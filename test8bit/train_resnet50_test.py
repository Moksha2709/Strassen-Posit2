"""
train_resnet50_test.py
-----------------------
Single dataset / single seed TEST run for a CIFAR-style ResNet50, matching the
data pipeline used for ResNet20 in this project (recovered from eval_calibrated.py,
since train_overnight.py wasn't available).

Once this confirms the pipeline works end-to-end, extend `datasets`/`seeds` in
main() to run the full 6-dataset x 2-seed sweep like ResNet20.

Run: python train_resnet50_test.py
"""

import os
import random
import time
import argparse

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision
import torchvision.transforms as transforms


# =============================================================================
# Reproducibility
# =============================================================================
def set_seed(seed):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


# =============================================================================
# Dataset configs — copied verbatim from eval_calibrated.py so weights stay
# comparable / droppable into the same eval scripts as ResNet20.
# =============================================================================
DATASETS = {
    'mnist':    {'tv_name': 'MNIST',        'num_classes': 10,  'in_channels': 1,
                 'mean': (0.1307,),          'std': (0.3081,)},
    'fmnist':   {'tv_name': 'FashionMNIST', 'num_classes': 10,  'in_channels': 1,
                 'mean': (0.2860,),          'std': (0.3530,)},
    'emnist':   {'tv_name': 'EMNIST',       'num_classes': 47,  'in_channels': 1,
                 'mean': (0.1736,),          'std': (0.3248,)},
    'svhn':     {'tv_name': 'SVHN',         'num_classes': 10,  'in_channels': 3,
                 'mean': (0.4377, 0.4438, 0.4728), 'std': (0.1980, 0.2010, 0.1970)},
    'cifar10':  {'tv_name': 'CIFAR10',      'num_classes': 10,  'in_channels': 3,
                 'mean': (0.4914, 0.4822, 0.4465), 'std': (0.2023, 0.1994, 0.2010)},
    'cifar100': {'tv_name': 'CIFAR100',     'num_classes': 100, 'in_channels': 3,
                 'mean': (0.5071, 0.4867, 0.4408), 'std': (0.2675, 0.2565, 0.2761)},
}

SEEDS = [42, 123]  # matches the seed42 weights already present; add a 2nd seed later


def get_transforms(cfg, train: bool, name: str = ''):
    norm = transforms.Normalize(cfg['mean'], cfg['std'])
    allow_hflip = name not in ('svhn', 'mnist', 'fmnist', 'emnist')
    if cfg['in_channels'] == 1:
        if train:
            return transforms.Compose([transforms.Resize(36),
                                        transforms.RandomCrop(32),
                                        transforms.ToTensor(), norm])
        return transforms.Compose([transforms.Resize(32), transforms.ToTensor(), norm])
    else:
        if train:
            aug = [transforms.RandomCrop(32, padding=4)]
            if allow_hflip:
                aug.append(transforms.RandomHorizontalFlip())
            return transforms.Compose(aug + [transforms.ToTensor(), norm])
        return transforms.Compose([transforms.ToTensor(), norm])


def _make_dataset(tv, cfg, name, train, data_root):
    tr_t = get_transforms(cfg, train=train, name=name)
    if tv == 'SVHN':
        return torchvision.datasets.SVHN(
            data_root, split='train' if train else 'test',
            download=True, transform=tr_t)
    elif tv == 'EMNIST':
        return torchvision.datasets.EMNIST(
            data_root, split='balanced', train=train,
            download=True, transform=tr_t)
    else:
        return getattr(torchvision.datasets, tv)(
            data_root, train=train, download=True, transform=tr_t)


def get_loaders(name, cfg, data_root='./data', batch_size=128, num_workers=2):
    tv = cfg['tv_name']
    train_ds = _make_dataset(tv, cfg, name, train=True, data_root=data_root)
    test_ds = _make_dataset(tv, cfg, name, train=False, data_root=data_root)
    train_loader = torch.utils.data.DataLoader(
        train_ds, batch_size=batch_size, shuffle=True,
        num_workers=num_workers, pin_memory=True, drop_last=True)
    test_loader = torch.utils.data.DataLoader(
        test_ds, batch_size=100, shuffle=False,
        num_workers=num_workers, pin_memory=True)
    return train_loader, test_loader


# =============================================================================
# CIFAR-style ResNet50 (bottleneck architecture, 3x3 stem, no maxpool)
#
# Keeps the standard ImageNet ResNet50 bottleneck stage layout (3,4,6,3 blocks;
# 256/512/1024/2048 channel stages) but replaces the 7x7 stride-2 stem + maxpool
# with a 3x3 stride-1 stem, matching the ResNet20 CIFAR pipeline (32x32 in,
# only 3 spatial downsamples total: 32->16->8->4).
# =============================================================================
class Bottleneck(nn.Module):
    expansion = 4

    def __init__(self, in_planes, planes, stride=1):
        super().__init__()
        self.conv1 = nn.Conv2d(in_planes, planes, kernel_size=1, bias=False)
        self.bn1 = nn.BatchNorm2d(planes)
        self.conv2 = nn.Conv2d(planes, planes, kernel_size=3, stride=stride, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(planes)
        self.conv3 = nn.Conv2d(planes, planes * self.expansion, kernel_size=1, bias=False)
        self.bn3 = nn.BatchNorm2d(planes * self.expansion)

        self.shortcut = nn.Sequential()
        if stride != 1 or in_planes != planes * self.expansion:
            self.shortcut = nn.Sequential(
                nn.Conv2d(in_planes, planes * self.expansion, kernel_size=1, stride=stride, bias=False),
                nn.BatchNorm2d(planes * self.expansion),
            )

    def forward(self, x):
        out = F.relu(self.bn1(self.conv1(x)))
        out = F.relu(self.bn2(self.conv2(out)))
        out = self.bn3(self.conv3(out))
        return F.relu(out + self.shortcut(x))


class ResNet50(nn.Module):
    def __init__(self, num_classes=10, in_channels=3):
        super().__init__()
        self.in_planes = 64
        # CIFAR-style stem: 3x3, stride 1, no maxpool (vs. ImageNet's 7x7 s2 + maxpool)
        self.conv1 = nn.Conv2d(in_channels, 64, kernel_size=3, stride=1, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(64)
        self.layer1 = self._make_layer(64, 3, stride=1)   # 32x32 -> 32x32
        self.layer2 = self._make_layer(128, 4, stride=2)  # 32x32 -> 16x16
        self.layer3 = self._make_layer(256, 6, stride=2)  # 16x16 -> 8x8
        self.layer4 = self._make_layer(512, 3, stride=2)  # 8x8   -> 4x4
        self.linear = nn.Linear(512 * Bottleneck.expansion, num_classes)

    def _make_layer(self, planes, num_blocks, stride):
        strides = [stride] + [1] * (num_blocks - 1)
        layers = []
        for s in strides:
            layers.append(Bottleneck(self.in_planes, planes, s))
            self.in_planes = planes * Bottleneck.expansion
        return nn.Sequential(*layers)

    def forward(self, x):
        out = F.relu(self.bn1(self.conv1(x)))
        out = self.layer1(out)
        out = self.layer2(out)
        out = self.layer3(out)
        out = self.layer4(out)
        out = F.adaptive_avg_pool2d(out, 1)
        out = out.view(out.size(0), -1)
        return self.linear(out)


def get_model(name, cfg):
    if name == 'resnet50':
        return ResNet50(num_classes=cfg['num_classes'], in_channels=cfg['in_channels'])
    raise ValueError(f"Unknown model: {name}")


# =============================================================================
# Standard CIFAR-ResNet training recipe (He et al. 2015 style):
# SGD, momentum 0.9, wd 1e-4, LR 0.1 with step decay, batch 128.
# NOT confirmed to be identical to train_overnight.py's ResNet20 recipe —
# swap these in if your friend's script turns out to differ.
# =============================================================================
def train_one_combo(model_name, dataset_name, seed, epochs, lr, device, out_dir='.'):
    set_seed(seed)
    cfg = DATASETS[dataset_name]

    train_loader, test_loader = get_loaders(dataset_name, cfg, batch_size=128, num_workers=2)

    model = get_model(model_name, cfg).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.SGD(model.parameters(), lr=lr, momentum=0.9,
                                 weight_decay=1e-4, nesterov=True)
    milestones = [int(epochs * 0.5), int(epochs * 0.75)]
    scheduler = torch.optim.lr_scheduler.MultiStepLR(optimizer, milestones=milestones, gamma=0.1)

    best_acc = 0.0
    for epoch in range(epochs):
        model.train()
        t0 = time.time()
        running_loss, correct, total = 0.0, 0, 0
        for x, y in train_loader:
            x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
            optimizer.zero_grad()
            out = model(x)
            loss = criterion(out, y)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * x.size(0)
            correct += (out.argmax(1) == y).sum().item()
            total += x.size(0)
        scheduler.step()

        train_acc = 100.0 * correct / total
        test_acc = evaluate(model, test_loader, device)
        best_acc = max(best_acc, test_acc)
        print(f"[{dataset_name} seed{seed}] epoch {epoch+1}/{epochs} "
              f"loss={running_loss/total:.4f} train_acc={train_acc:.2f}% "
              f"test_acc={test_acc:.2f}% ({time.time()-t0:.1f}s)")

    weights_path = os.path.join(out_dir, f'weights_{model_name}_{dataset_name}_seed{seed}_fp32.pth')
    torch.save(model.state_dict(), weights_path)
    print(f"Saved: {weights_path} (best test_acc={best_acc:.2f}%)")
    return best_acc


@torch.no_grad()
def evaluate(model, loader, device):
    model.eval()
    correct, total = 0, 0
    for x, y in loader:
        x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
        out = model(x)
        correct += (out.argmax(1) == y).sum().item()
        total += x.size(0)
    return 100.0 * correct / total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dataset', default='cifar10', choices=list(DATASETS.keys()))
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--epochs', type=int, default=10, help='short test run; use 150-200 for the real sweep')
    parser.add_argument('--lr', type=float, default=0.1)
    args = parser.parse_args()

    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"Device: {device}")
    print(f"TEST RUN: resnet50 | {args.dataset} | seed={args.seed} | epochs={args.epochs}")

    train_one_combo('resnet50', args.dataset, args.seed, args.epochs, args.lr, device)


if __name__ == '__main__':
    main()

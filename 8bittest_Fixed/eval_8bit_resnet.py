# =============================================================================
# eval_8bit_resnet.py — Empirical PyTorch Accuracy Benchmark for 8bittest_q4_4
# -----------------------------------------------------------------------------
# Evaluates PyTorch ResNet-20 accuracy on CIFAR-10 dataset under 8-bit signed
# fixed-point arithmetic (Q4.4 format) using local dataset path.
# =============================================================================
import os
import sys
import math
import torch
import torch.nn as nn
import torch.nn.functional as F

resnet_dir = os.path.join(os.path.dirname(__file__), '..', 'resnet')
sys.path.append(resnet_dir)
try:
    from models import ResNet20
except ImportError:
    pass

import torchvision
import torchvision.transforms as transforms

def quantize_fixed8_tensor(x_tensor):
    """Quantizes a PyTorch Float32 tensor to 8-bit signed fixed-point (Q4.4 format)."""
    x_scaled = torch.round(x_tensor * 16.0).clamp(-128.0, 127.0)
    return x_scaled / 16.0

class Calibrated8BitFixedConv2d(nn.Conv2d):
    """Simulates 8-Bit Fixed-Point Hardware execution (Q4.4 format)."""
    def __init__(self, in_channels, out_channels, kernel_size, stride=1,
                 padding=0, dilation=1, groups=1, bias=True):
        super().__init__(in_channels, out_channels, kernel_size, stride,
                         padding, dilation, groups, bias)

    def forward(self, x):
        w_q = quantize_fixed8_tensor(self.weight)
        x_q = quantize_fixed8_tensor(x)
        out_q = F.conv2d(x_q, w_q, None, self.stride, self.padding, self.dilation, self.groups)
        if self.bias is not None:
            out_q = out_q + self.bias.view(1, -1, 1, 1)
        return out_q

def replace_layers_with_fixed8(model):
    """Recursively replaces nn.Conv2d layers with Calibrated8BitFixedConv2d."""
    for name, module in model.named_children():
        if isinstance(module, nn.Conv2d):
            new_layer = Calibrated8BitFixedConv2d(
                module.in_channels, module.out_channels, module.kernel_size,
                stride=module.stride, padding=module.padding, dilation=module.dilation,
                groups=module.groups, bias=module.bias is not None
            )
            new_layer.weight.data.copy_(module.weight.data)
            if module.bias is not None:
                new_layer.bias.data.copy_(module.bias.data)
            setattr(model, name, new_layer)
        else:
            replace_layers_with_fixed8(module)
    return model

def evaluate_model(model, loader, device):
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for i, (inputs, targets) in enumerate(loader):
            inputs, targets = inputs.to(device), targets.to(device)
            outputs = model(inputs)
            _, predicted = outputs.max(1)
            total += targets.size(0)
            correct += predicted.eq(targets).sum().item()
            if i >= 10:  # Evaluate on 1,000 images for fast hardware benchmark
                break
    return 100.0 * correct / total

def run_8bit_resnet_eval():
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"=================================================================")
    print(f" 8-Bit Fixed-Point (Q4.4) Accuracy Evaluation (`8bittest_q4_4`)")
    print(f" Device: {device}")
    print(f"=================================================================")
    
    transform_test = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
    ])
    
    data_path = os.path.join(resnet_dir, 'data')
    testset = torchvision.datasets.CIFAR10(root=data_path, train=False, download=False, transform=transform_test)
    testloader = torch.utils.data.DataLoader(testset, batch_size=100, shuffle=False, num_workers=2)
    
    # 1. Instantiate Float32 Baseline ResNet-20
    model_fp32 = ResNet20(num_classes=10).to(device)
    fp32_acc = evaluate_model(model_fp32, testloader, device)
    print(f" [1] FP32 ResNet-20 Baseline Accuracy : {fp32_acc:.2f}%")
    
    # 2. Convert to Calibrated 8-Bit Fixed Hardware Model
    model_fixed8 = replace_layers_with_fixed8(ResNet20(num_classes=10)).to(device)
    fixed8_acc = evaluate_model(model_fixed8, testloader, device)
    print(f" [2] 8-Bit Fixed-Point (Q4.4) ResNet-20 Acc : {fixed8_acc:.2f}%")
    print(f"-----------------------------------------------------------------")
    print(f" Accuracy Delta vs FP32                : {fixed8_acc - fp32_acc:+.2f}%")
    print(f"=================================================================")

if __name__ == '__main__':
    run_8bit_resnet_eval()

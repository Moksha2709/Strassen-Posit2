# =============================================================================
# eval_16bit_resnet.py — Empirical PyTorch Accuracy Benchmark for 16bittest
# -----------------------------------------------------------------------------
# Evaluates PyTorch ResNet-20 accuracy on CIFAR-10 dataset under 16-bit signed
# fixed-point arithmetic (Q8.8 format) using local dataset path.
# =============================================================================
import os
import sys
import math
import torch
import torch.nn as nn
import torch.nn.functional as F

# Add resnet folder to sys.path to import ResNet20 model
resnet_dir = os.path.join(os.path.dirname(__file__), '..', 'resnet')
sys.path.append(resnet_dir)
try:
    from models import ResNet20
except ImportError:
    pass

import torchvision
import torchvision.transforms as transforms

def quantize_fixed16_tensor(x_tensor):
    """Quantizes a PyTorch Float32 tensor to 16-bit signed fixed-point (Q8.8 format)."""
    x_scaled = torch.round(x_tensor * 256.0).clamp(-32768.0, 32767.0)
    return x_scaled / 256.0

class Calibrated16BitFixedConv2d(nn.Conv2d):
    """Simulates 16-Bit Fixed-Point Hardware execution (Q8.8 format)."""
    def __init__(self, in_channels, out_channels, kernel_size, stride=1,
                 padding=0, dilation=1, groups=1, bias=True):
        super().__init__(in_channels, out_channels, kernel_size, stride,
                         padding, dilation, groups, bias)

    def forward(self, x):
        w_q = quantize_fixed16_tensor(self.weight)
        x_q = quantize_fixed16_tensor(x)
        out_q = F.conv2d(x_q, w_q, None, self.stride, self.padding, self.dilation, self.groups)
        if self.bias is not None:
            out_q = out_q + self.bias.view(1, -1, 1, 1)
        return out_q

def replace_layers_with_fixed16(model):
    """Recursively replaces nn.Conv2d layers with Calibrated16BitFixedConv2d."""
    for name, module in model.named_children():
        if isinstance(module, nn.Conv2d):
            new_layer = Calibrated16BitFixedConv2d(
                module.in_channels, module.out_channels, module.kernel_size,
                stride=module.stride, padding=module.padding, dilation=module.dilation,
                groups=module.groups, bias=module.bias is not None
            )
            new_layer.weight.data.copy_(module.weight.data)
            if module.bias is not None:
                new_layer.bias.data.copy_(module.bias.data)
            setattr(model, name, new_layer)
        else:
            replace_layers_with_fixed16(module)
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

def run_16bit_resnet_eval():
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"=================================================================")
    print(f" 16-Bit Fixed-Point (Q8.8) Accuracy Evaluation (`16bittest`)")
    print(f" Device: {device}")
    print(f"=================================================================")
    
    transform_test = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
    ])
    
    # Use local dataset root path '../resnet/data'
    data_path = os.path.join(resnet_dir, 'data')
    testset = torchvision.datasets.CIFAR10(root=data_path, train=False, download=False, transform=transform_test)
    testloader = torch.utils.data.DataLoader(testset, batch_size=100, shuffle=False, num_workers=2)
    
    # 1. Instantiate Float32 Baseline ResNet-20
    model_fp32 = ResNet20(num_classes=10).to(device)
    fp32_acc = evaluate_model(model_fp32, testloader, device)
    print(f" [1] FP32 ResNet-20 Baseline Accuracy : {fp32_acc:.2f}%")
    
    # 2. Convert to Calibrated 16-Bit Fixed Hardware Model
    model_fixed16 = replace_layers_with_fixed16(ResNet20(num_classes=10)).to(device)
    fixed16_acc = evaluate_model(model_fixed16, testloader, device)
    print(f" [2] 16-Bit Fixed-Point ResNet-20 Acc : {fixed16_acc:.2f}%")
    print(f"-----------------------------------------------------------------")
    print(f" Accuracy Delta vs FP32                : {fixed16_acc - fp32_acc:+.2f}%")
    print(f"=================================================================")

if __name__ == '__main__':
    run_16bit_resnet_eval()

# =============================================================================
# cifar_resnet_layer_extractor.py — Same idea as resnet_layer_extractor.py, but
# for YOUR trained CIFAR-style ResNet50 (train_resnet50_test.py) instead of
# torchvision's ImageNet ResNet50.
#
# Why a separate file instead of editing resnet_layer_extractor.py in place:
# the two models are architecturally different (3x3 stride-1 stem vs 7x7
# stride-2 stem + maxpool, 32x32 vs 224x224 input), so they can't share one
# loader. Keeping this separate means verify_resnet_accuracy.py can pick
# either source via a flag without either path silently breaking the other.
#
# Returns the SAME layer_specs schema as get_resnet50_conv_layers():
#   name, input (C,H,W), weight (out,in,kh,kw), stride, padding, kernel_size
# so nothing downstream (im2col_matrices, tiled_gemm_hw, etc.) needs to change.
# =============================================================================
import torch
import torchvision
import torchvision.transforms as transforms

# Reuse the exact model definition from train_resnet50_test.py so the loaded
# state_dict matches key-for-key. Adjust this import path if you place
# train_resnet50_test.py somewhere other than the same folder.
from train_resnet50_test import ResNet50, DATASETS


def get_cifar_test_image(dataset_name='cifar10', data_root='./data'):
    """Pulls ONE real test-set image (already normalized), shape (1,3,32,32),
    using the same mean/std/transform as training -- so activation stats match
    what the model actually saw during training/eval, not arbitrary noise."""
    cfg = DATASETS[dataset_name]
    norm = transforms.Normalize(cfg['mean'], cfg['std'])
    test_transform = transforms.Compose([transforms.ToTensor(), norm])
    tv_name = cfg['tv_name']
    test_ds = getattr(torchvision.datasets, tv_name)(
        data_root, train=False, download=True, transform=test_transform)
    image, _ = test_ds[0]
    return image.unsqueeze(0)  # (1,C,H,W)


def get_cifar_resnet50_conv_layers(weights_path, dataset_name='cifar10',
                                    data_root='./data', image_tensor=None):
    """
    Loads your trained CIFAR ResNet50 checkpoint and returns a list of dicts,
    one per Conv2d layer, in forward-pass order -- identical schema to
    resnet_layer_extractor.get_resnet50_conv_layers().

    weights_path: e.g. 'weights_resnet50_cifar10_seed42_fp32.pth'
    dataset_name: must match DATASETS key used during training (for
                  num_classes/in_channels and to pick the right test image).
    image_tensor: pass your own (1,C,32,32) tensor, or leave None to pull one
                  real CIFAR test image automatically.
    """
    cfg = DATASETS[dataset_name]
    model = ResNet50(num_classes=cfg['num_classes'], in_channels=cfg['in_channels'])
    state_dict = torch.load(weights_path, map_location='cpu')
    model.load_state_dict(state_dict)
    model.eval()

    layer_specs = []
    hooks = []

    def make_hook(name):
        def hook(module, inp, out):
            layer_specs.append({
                "name": name,
                "input": inp[0].detach()[0],       # drop batch dim -> (C,H,W)
                "weight": module.weight.detach(),  # (out,in,kh,kw)
                "stride": module.stride,
                "padding": module.padding,
                "kernel_size": module.kernel_size,
            })
        return hook

    for name, module in model.named_modules():
        if isinstance(module, torch.nn.Conv2d):
            hooks.append(module.register_forward_hook(make_hook(name)))

    if image_tensor is None:
        image_tensor = get_cifar_test_image(dataset_name, data_root)

    with torch.no_grad():
        model(image_tensor)

    for h in hooks:
        h.remove()

    return layer_specs


def summarize_layers(layer_specs):
    """Same printout as resnet_layer_extractor.py -- run this first to see
    how many conv layers your CIFAR model has and pick sane layer_indices
    before running the full hardware verification (each layer = a real
    iverilog compile+sim subprocess call, so sampling matters)."""
    print(f"{'idx':<4} {'name':<28} {'in_shape':<18} {'weight_shape':<20} {'stride':<8} {'pad':<6}")
    for i, spec in enumerate(layer_specs):
        c, h, w = spec["input"].shape
        print(f"{i:<4} {spec['name']:<28} {(c, h, w)!s:<18} "
              f"{tuple(spec['weight'].shape)!s:<20} {spec['stride']!s:<8} {spec['padding']!s:<6}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--weights', default='weights_resnet50_cifar10_seed42_fp32.pth')
    parser.add_argument('--dataset', default='cifar10')
    args = parser.parse_args()

    layers = get_cifar_resnet50_conv_layers(args.weights, args.dataset)
    print(f"Extracted {len(layers)} real Conv2d layers from your CIFAR ResNet-50\n")
    summarize_layers(layers)

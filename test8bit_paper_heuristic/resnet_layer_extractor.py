# =============================================================================
# resnet_layer_extractor.py — Pulls REAL ResNet-50 conv layer specs, weights,
# and activations directly from torchvision, matching the paper's approach of
# testing on the actual network rather than synthetic shapes.
# =============================================================================
import torch
import torchvision.models as models


def get_resnet50_conv_layers(input_size=224, pretrained=True, image_tensor=None):
    """
    Returns a list of dicts, one per Conv2d layer in ResNet-50, in forward-pass
    order, each containing:
        name       : layer name (e.g. 'layer1.0.conv2')
        input      : real activation tensor fed INTO this conv, shape (C,H,W)
        weight     : real (or randomly-init) weight tensor, shape (out,in,kh,kw)
        stride     : (sH, sW)
        padding    : (pH, pW)
        kernel_size: (kH, kW)

    Because this runs a real forward pass through the real (pretrained) model,
    every layer's input activation reflects the actual statistics that layer
    sees in practice -- not random noise -- which is what the paper's ResNet
    evaluation methodology relies on.

    Pass a real image tensor (1,3,H,W) via image_tensor for the most faithful
    activations. If omitted, a random tensor is used, which still exercises
    the real weights/BN but won't reflect a real image's activation stats.
    """
    weights = models.ResNet50_Weights.IMAGENET1K_V2 if pretrained else None
    model = models.resnet50(weights=weights)
    model.eval()

    layer_specs = []
    hooks = []

    def make_hook(name):
        def hook(module, inp, out):
            layer_specs.append({
                "name": name,
                "input": inp[0].detach()[0],       # drop batch dim -> (C,H,W)
                "weight": module.weight.detach(),   # (out,in,kh,kw)
                "stride": module.stride,
                "padding": module.padding,
                "kernel_size": module.kernel_size,
            })
        return hook

    for name, module in model.named_modules():
        if isinstance(module, torch.nn.Conv2d):
            hooks.append(module.register_forward_hook(make_hook(name)))

    if image_tensor is None:
        image_tensor = torch.randn(1, 3, input_size, input_size)

    with torch.no_grad():
        model(image_tensor)

    for h in hooks:
        h.remove()

    return layer_specs


def summarize_layers(layer_specs):
    """Quick printout to sanity-check what got extracted before running the
    full test -- useful for picking which layers to sample."""
    print(f"{'idx':<4} {'name':<28} {'in_shape':<18} {'weight_shape':<20} {'stride':<8} {'pad':<6}")
    for i, spec in enumerate(layer_specs):
        c, h, w = spec["input"].shape
        print(f"{i:<4} {spec['name']:<28} {(c, h, w)!s:<18} "
              f"{tuple(spec['weight'].shape)!s:<20} {spec['stride']!s:<8} {spec['padding']!s:<6}")


if __name__ == "__main__":
    layers = get_resnet50_conv_layers()
    print(f"Extracted {len(layers)} real Conv2d layers from ResNet-50\n")
    summarize_layers(layers)

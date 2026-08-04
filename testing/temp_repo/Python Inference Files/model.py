from conv import *
from converters import *
from matmul import *
from pooling import *

import torch
import torch.nn as nn
import torch.nn.functional as F

class LeNetAvgPool(nn.Module):
    def __init__(self):
        super(LeNetAvgPool, self).__init__()
        self.conv1 = nn.Conv2d(1, 6, 5)       # Changed input channel to 1 for MNIST
        self.conv2 = nn.Conv2d(6, 16, 5)
        self.fc1   = nn.Linear(16*4*4, 120)   # 28x28 → 24x24 (conv) → 12x12 (pool) → 8x8 (conv) → 4x4 (pool)
        self.fc2   = nn.Linear(120, 84)
        self.fc3   = nn.Linear(84, 10)

    def forward(self, x):
        x = F.relu(self.conv1(x))      
        x = F.avg_pool2d(x, 2)         
        x = F.relu(self.conv2(x))      
        x = F.avg_pool2d(x, 2)         
        x = x.view(x.size(0), -1)      
        x = F.relu(self.fc1(x))        
        x = F.relu(self.fc2(x))        
        x = self.fc3(x)                
        return x

def relu(a,n=8,es=1):
    zero = PCPosit(0,mode='bits',nbits=n,es=es)
    if(a>zero):
        return a
    else:
        return zero
    
def tensor_to_posit(tensor, n=8, es=1):
    """
    Convert a PyTorch tensor or NumPy array to nested list of PCPosit values.
    """
    tensor = tensor.detach().numpy() if isinstance(tensor, torch.Tensor) else tensor
    return [
        [
            [
                [PCPosit(int(float_to_posit(n, es, float(val)), 2), mode='bits', nbits=n, es=es)
                 for val in row]
                for row in channel]
            for channel in out_ch]
        for out_ch in tensor
    ]

def bias_to_posit(bias, n=8, es=1):
    return [PCPosit(int(float_to_posit(n, es, float(val)), 2), mode='bits', nbits=n, es=es) for val in bias.detach().numpy()]


def model_inference(A, n=8, es=1):
    """
    Performs step-by-step inference on the LeNetAvgPool model using custom posit-based ops.

    Args:
        A (list): Input image as a 3D list with shape [1][H][W]
        n (int): Posit nbits
        es (int): Posit exponent size
    Returns:
        list: Logits from the final FC layer (length 10)
    """
    #########################
    ## Layer 1: Conv2d
    #########################
    # Load model
    model = LeNetAvgPool()  # Instantiate the model
    model.load_state_dict(torch.load("model_avg.pth", map_location=torch.device('cpu')))
    model.eval()
    print('1')
    # Get weights and biases
    # conv1_weight = PCPosit(int(float_to_posit(n,es,model.conv1.weight.detach().numpy()),2),mode='bits',nbits=n,es=es)  # [6, 1, 5, 5]
    # conv1_bias   = PCPosit(int(float_to_posit(n,es,model.conv1.bias.detach().numpy()),2),mode='bits',nbits=n,es=es)    # [6]

    # conv2_weight = PCPosit(int(float_to_posit(n,es,model.conv2.weight.detach().numpy()),2),mode='bits',nbits=n,es=es)  # [16, 6, 5, 5]
    # conv2_bias   = PCPosit(int(float_to_posit(n,es,model.conv2.bias.detach().numpy()),2),mode='bits',nbits=n,es=es)    # [16]

    # fc1_weight = PCPosit(int(float_to_posit(n,es,model.fc1.weight.detach().numpy()),2),mode='bits',nbits=n,es=es)      # [120, 256]
    # fc1_bias   = PCPosit(int(float_to_posit(n,es,model.fc1.bias.detach().numpy()),2),mode='bits',nbits=n,es=es)        # [120]

    # fc2_weight = PCPosit(int(float_to_posit(n,es,model.fc2.weight.detach().numpy()),2),mode='bits',nbits=n,es=es)      # [84, 120]
    # fc2_bias   = PCPosit(int(float_to_posit(n,es,model.fc2.bias.detach().numpy()),2),mode='bits',nbits=n,es=es)        # [84]

    # fc3_weight = PCPosit(int(float_to_posit(n,es,model.fc3.weight.detach().numpy()),2),mode='bits',nbits=n,es=es)      # [10, 84]
    # fc3_bias   = PCPosit(int(float_to_posit(n,es,model.fc3.bias.detach().numpy()),2),mode='bits',nbits=n,es=es)        # [10]
    
    conv1_weight = tensor_to_posit(model.conv1.weight, n, es)  # shape: [6, 1, 5, 5]
    conv1_bias   = bias_to_posit(model.conv1.bias, n, es)      # shape: [6]

    conv2_weight = tensor_to_posit(model.conv2.weight, n, es)  # shape: [16, 6, 5, 5]
    conv2_bias   = bias_to_posit(model.conv2.bias, n, es)      # shape: [16]

    fc1_weight = [
        [PCPosit(int(float_to_posit(n, es, float(val)), 2), mode='bits', nbits=n, es=es)
        for val in row]
        for row in model.fc1.weight.detach().numpy()
    ]
    fc1_bias = bias_to_posit(model.fc1.bias, n, es)

    fc2_weight = [
        [PCPosit(int(float_to_posit(n, es, float(val)), 2), mode='bits', nbits=n, es=es)
        for val in row]
        for row in model.fc2.weight.detach().numpy()
    ]
    fc2_bias = bias_to_posit(model.fc2.bias, n, es)

    fc3_weight = [
        [PCPosit(int(float_to_posit(n, es, float(val)), 2), mode='bits', nbits=n, es=es)
        for val in row]
        for row in model.fc3.weight.detach().numpy()
    ]
    fc3_bias = bias_to_posit(model.fc3.bias, n, es)
    print('2')
    
    #########################
    # Conv1 + ReLU + AvgPool
    #########################
    x = conv2D(A, conv1_weight, n=n, es=es, posit=True)
    print('3')
    # for i in range(len(x)):
    #     for h in range(len(x[0])):
    #         for w in range(len(x[0][0])):
    #             x[i][h][w] = x[i][h][w] + PCPosit(float_to_posit(n, es, conv1_bias[i]), mode='bits', nbits=n, es=es)
    #             x[i][h][w] = relu(x[i][h][w])  # Assuming you’ve defined relu inside PCPosit
    for i in range(len(x)):
        for h in range(len(x[0])):
            for w in range(len(x[0][0])):
                x[i][h][w] = x[i][h][w] + conv1_bias[i]
                x[i][h][w] = relu(x[i][h][w])  # Assuming you’ve defined relu inside PCPosit
    print('4')
    x = [avg_pool(xi, n=n, es=es, posit=True) for xi in x]  # list of 6 channels
    print('5')
    #########################
    # Conv2 + ReLU + AvgPool
    #########################
    x = conv2D(x, conv2_weight, n=n, es=es, posit=True)
    # for i in range(len(x)):
    #     for h in range(len(x[0])):
    #         for w in range(len(x[0][0])):
    #             x[i][h][w] = x[i][h][w] + PCPosit(float_to_posit(n, es, conv2_bias[i]), mode='bits', nbits=n, es=es)
    #             x[i][h][w] = relu(x[i][h][w])
    print('6')
    for i in range(len(x)):
        for h in range(len(x[0])):
            for w in range(len(x[0][0])):
                x[i][h][w] = x[i][h][w] + conv2_bias[i]
                x[i][h][w] = relu(x[i][h][w])
    print('7')            
    

    x = [avg_pool(xi, n=n, es=es, posit=True) for xi in x]  # list of 16 channels
    print('8')
    #########################
    # Flatten
    #########################
    flat = []
    for ch in x:
        for row in ch:
            for val in row:
                flat.append(val)
    print('9')
    #########################
    # FC1 + ReLU
    #########################
    out = matmul_posit(flat, fc1_weight,n=n, es=es)
    for i in range(len(out)):
        out[i] = out[i] + fc1_bias[i]
    out = [relu(val) for val in out]
    print('10')
    #########################
    # FC2 + ReLU
    #########################
    out = matmul_posit(out, fc2_weight, n=n, es=es)
    for i in range(len(out)):
        out[i] = out[i] + fc2_bias[i]
    out = [relu(val) for val in out]
    print('11')
    #########################
    # FC3 (Logits)
    #########################
    out = matmul_posit(out, fc3_weight, n=n, es=es)
    for i in range(len(out)):
        out[i] = out[i] + fc3_bias[i]

    return out

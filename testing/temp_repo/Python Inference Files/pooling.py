from sgposit.pcposit import PCPosit
from converters import *
from matmul import *

def avg_pool(A,n=8,es=1,posit=True):
    """
    Performs 2x2 average pooling with stride 2 on a 2D input image A.
    
    Args:
        A (list of list): 2D input image (single channel)
    
    Returns:
        list of list: Pooled output
    """
    H = len(A)
    W = len(A[0])
    out_H = H // 2
    out_W = W // 2
    if(posit):
        denominator = PCPosit(int(float_to_posit(n,es,4.0),2),mode='bits',nbits=n,es=es)
        # print('hi')
    else:
        denominator = 4
    pooled = []
    for i in range(0, H - 1, 2):  # stride 2
        row = []
        for j in range(0, W - 1, 2):  # stride 2
            if(posit):
                pool_sum0 = PCPosit(0, mode='bits', nbits=n, es=es)
                pool_sum1 = PCPosit(0, mode='bits', nbits=n, es=es)
                pool_sum = PCPosit(0, mode='bits', nbits=n, es=es)
                avg_val = PCPosit(0, mode='bits', nbits=n, es=es)
                # print(type(avg_val),type(pool_sum),type(pool_sum0), type(pool_sum1))
                # print('1')
            else:
                pool_sum0 = 0
                pool_sum1 = 0
                pool_sum = 0
                avg_val = 0
            pool_sum0 = A[i][j] + A[i][j+1]
            pool_sum1 = A[i+1][j] + A[i+1][j+1]
            pool_sum = pool_sum0 + pool_sum1
            # print(type(avg_val),type(pool_sum),type(pool_sum0), type(pool_sum1))
            avg_val = pool_sum / denominator
            row.append(avg_val)
        pooled.append(row)

    return pooled


if __name__ == "__main__":
    n = 8
    es = 1
    
    input_img = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9,10,11,12],
        [13,14,15,16]
    ]

    for i in range(len(input_img)):
        for j in range(len(input_img[0])):
            input_img[i][j] +=10

    input_img_posit = convertMatrixToPOSIT(input_img,n=n,es=es)

    result = avg_pool(input_img,posit=False)

    print("Avg Pooled Output:")
    for row in result:
        print(row)
        
    result = avg_pool(input_img_posit,posit=True)

    print("Avg Pooled Output:")
    mat_print(result)
import numpy as np
import os
import struct
from sklearn.neighbors import NearestNeighbors


n_samples = 1_060_000  
n_features = 128       
top_k = 100            
random_state = 42

# Output paths (in data/uniform directory)
output_dir = "data/uniform"
os.makedirs(output_dir, exist_ok=True)

base_path = os.path.join(output_dir, "uniform_base.fvecs")
learn_path = os.path.join(output_dir, "uniform_learn.fvecs")
query_path = os.path.join(output_dir, "uniform_query.fvecs")
gt_path = os.path.join(output_dir, "uniform_groundtruth.ivecs")

# Save functions
def save_fvecs(filename, data):
    """
    Save numpy array to .fvecs format.
    :param filename: Output file path
    :param data: Numpy array of shape (n_samples, n_dims)
    """
    with open(filename, 'wb') as f:
        for vec in data:
            f.write(struct.pack('<i', len(vec)))  # Write dimension as int32
            f.write(struct.pack(f'<{len(vec)}f', *vec))  # Write vector as float32

def save_ivecs(filename, data):
    """
    Save numpy array to .ivecs format.
    :param filename: Output file path
    :param data: Numpy array of shape (n_samples, n_neighbors)
    """
    with open(filename, 'wb') as f:
        for vec in data:
            f.write(struct.pack('<i', len(vec)))  # Write number of neighbors as int32
            f.write(struct.pack(f'<{len(vec)}i', *vec))  # Write indices as int32

# Generate uniform random data
np.random.seed(random_state)
X = np.random.uniform(low=0.0, high=1.0, size=(n_samples, n_features)).astype(np.float32)

# Shuffle and split
indices = np.random.permutation(n_samples)
X_base = X[indices[:1000000]]   
X_learn = X[indices[1000000:1050000]]  
X_query = X[indices[1050000:]]  

# Save to .fvecs
save_fvecs(base_path, X_base)
save_fvecs(learn_path, X_learn)
save_fvecs(query_path, X_query)

# Compute groundtruth 100-NN
nn = NearestNeighbors(n_neighbors=top_k, algorithm='brute', metric='euclidean')
nn.fit(X_base)
_, neighbors = nn.kneighbors(X_query)
save_ivecs(gt_path, neighbors)

print(f"Uniform dataset generation complete. Saved to {output_dir}/")
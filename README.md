# OPT-SNG: Sparse Neighborhood Graph-Based Approximate Nearest Neighbor Search Revisited

This repository is the official implementation of the paper:

**"Sparse Neighborhood Graph-Based Approximate Nearest Neighbor Search Revisited: Theoretical Analysis and Optimization"**

We present OPT-SNG, a principled framework for analyzing and optimizing Sparse Neighborhood Graph (SNG) construction. Our method derives a closed-form analytical rule for selecting the truncation parameter $R$, eliminating the need for costly parameter sweep.

The file `full_version.pdf` contains the extended version of the paper, which complements the conference submission with full theoretical proofs.

## Compared Algorithms

We evaluate our optimization on three representative SNG-based ANNS algorithms:

| Algorithm | Description | Source |
|-----------|-------------|--------|
| **Vamana (DiskANN)** | SNG-based algorithm with RobustPrune | [microsoft/DiskANN](https://github.com/microsoft/DiskANN) |
| **NSG** | Navigating Spreading-out Graph | [ZJULearning/nsg](https://github.com/ZJULearning/nsg) |
| **HNSW** | Hierarchical Navigable Small World | [nmslib/hnswlib](https://github.com/nmslib/hnswlib) |

## Datasets

| Dataset | Cardinality | Dimension | Query Size | Download |
|---------|-------------|-----------|------------|----------|
| SIFT1M | 1,000,000 | 128 | 10,000 | [Texmex](http://corpus-texmex.irisa.fr/) |
| GIST1M | 1,000,000 | 960 | 1,000 | [Texmex](http://corpus-texmex.irisa.fr/) |
| DEEP1M | 1,000,000 | 256 | 1,000 | [Deep1M](https://www.cse.cuhk.edu.hk/systems/hash/gqr/datasets.html) |
| MSong | 992,272 | 420 | 200 | [MSong](https://www.cse.cuhk.edu.hk/systems/hash/gqr/datasets.html) |
| GloVe | 1,193,514 | 200 | 1,000 | [GloVe](https://www.cse.cuhk.edu.hk/systems/hash/gqr/datasets.html) |
| UNIFORM | 1,000,000 | 128 | 10,000 | Synthetic (generated) |

## Prerequisites

- **OS**: Ubuntu 22.04 LTS (recommended)
- **Compiler**: GCC 11.4+ with C++17 support
- **Dependencies**:
  - CMake 3.15+
  - Python 3.8+ (for scripts and data generation)
  - OpenMP (for parallel construction)

## Installation

### 1. Clone this repository
```bash
git clone https://github.com/YOUR_USERNAME/OPT-SNG.git
cd OPT-SNG
```

### 2. Build DiskANN
```bash
git clone https://github.com/microsoft/DiskANN.git
cd DiskANN
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j
cd ../..
```

### 3. Download and prepare datasets
```bash
# Download SIFT1M
mkdir -p data/sift
cd data/sift
wget ftp://ftp.irisa.fr/local/texmex/corpus/sift.tar.gz
tar -xzvf sift.tar.gz
cd ../..

# Convert to binary format (for DiskANN)
./DiskANN/build/apps/utils/fvecs_to_bin float data/sift/sift_base.fvecs data/sift/sift_base.fbin
./DiskANN/build/apps/utils/fvecs_to_bin float data/sift/sift_query.fvecs data/sift/sift_query.fbin
```

## Usage

### Parameter Optimization with OPT-SNG

Our method determines the optimal truncation parameter $R$ analytically:
```bash
# Step 1: Build reference graph with R = n^{2/3}
./DiskANN/build/apps/build_memory_index \
    --data_type float \
    --dist_fn l2 \
    --data_path data/sift/sift_base.fbin \
    --index_path_prefix data/sift/sift_index_ref \
    -R 100 \
    -L 100 \
    --alpha 1.2

# Step 2: Compute optimized R using our analytical formula & Build final index with optimized R
./DiskANN/build/apps/build_memory_index \
    --data_type float \
    --dist_fn l2 \
    --data_path data/sift/sift_base.fbin \
    --index_path_prefix data/sift/sift_index_opt \
    -R <OPTIMIZED_R> \
    -L 100 \
    --alpha 1.5
```

### Baseline: Binary Search Parameter Sweep
```bash
# Run binary search tuning for comparison
./scripts/sift_bi.sh
```

### Search and Evaluation
```bash
# Compute ground truth
./DiskANN/build/apps/utils/compute_groundtruth \
    --data_type float \
    --dist_fn l2 \
    --base_file data/sift/sift_base.fbin \
    --query_file data/sift/sift_query.fbin \
    --gt_file data/sift/sift_gt100 \
    --K 100

# Run search benchmark
./DiskANN/build/apps/search_memory_index \
    --data_type float \
    --dist_fn l2 \
    --index_path_prefix data/sift/sift_index_opt \
    --query_file data/sift/sift_query.fbin \
    --gt_file data/sift/sift_gt100 \
    -K 10 \
    -L 10 20 30 50 100 \
    --result_path results/sift_opt_results.txt
```

## Uniform Dataset (Synthetic)

The UNIFORM dataset is a synthetic dataset designed to evaluate the behavior of SNG-based methods under challenging conditions without favorable geometric structure. Data points are sampled independently and uniformly from the unit hypercube in 128 dimensions, following the standard uniform distribution commonly used in theoretical analysis.

This dataset is used to validate the robustness of OPT-SNG and to examine whether the proposed optimization remains effective when the data distribution does not exhibit clustering or low-dimensional structure.

The dataset can be generated using the provided script:

```bash
python3 scripts/generate_uniform_dataset.py
```

## Directory Structure
```
OPT-SNG/
├── DiskANN/                    # DiskANN library
├── NSG/
├── HNSW/
├── data/
│   ├── sift/                   # SIFT1M dataset
│   ├── gist/                   # GIST1M dataset
│   ├── deep/                   # DEEP1M dataset
│   ├── msong/                  # MSong dataset
│   ├── glove/                  # GloVe dataset
│   └── uniform/                # UNIFORM synthetic dataset
├── scripts/
│   └── sift_bi.sh   # Binary search baseline
├── results/                    # Experiment outputs
└── README.md
```

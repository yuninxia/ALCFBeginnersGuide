# AI Frameworks

### Users are assumed to know:
* How to use PyTorch

### Learning Goals:
* How to train a PyTorch model on Aurora GPUs



## Overview

ALCF supports popular Deep Learning Python libraries (AI Frameworks) on Aurora, such as [PyTorch](https://docs.alcf.anl.gov/aurora/data-science/frameworks/pytorch/) and [TensorFlow](https://docs.alcf.anl.gov/aurora/data-science/frameworks/tensorflow/), which are included in the [`frameworks` module](https://docs.alcf.anl.gov/aurora/data-science/python/#AIML-Framework-Module). 

In this session, we will focus on [PyTorch](https://pytorch.org/), a popular, open-source deep learning framework developed and released by Facebook. 
Assuming you have developed a PyTorch model on your laptop, we will see how to:

- Train your PyTorch model on a *GPU* on Aurora
- Train your model *in parallel* on multiple GPUs with PyTorch [Distributed Data Parallel](https://pytorch.org/tutorials/intermediate/ddp_tutorial.html)



## Intel Extension for PyTorch (IPEX)

[Intel Extension for PyTorch (IPEX)](https://pytorch.org/tutorials/recipes/recipes/intel_extension_for_pytorch.html) is an [open-source project](https://github.com/intel/intel-extension-for-pytorch) that extends PyTorch with optimizations for extra performance boost on Intel CPUs and enables the use of Intel GPUs. 

Along with importing the `torch` library, you need to import the `intel_extension_for_pytorch` library in order to detect Intel GPUs as `xpu` devices. 

> **Note**: It is [highly recommended](https://github.com/intel/intel-extension-for-pytorch/blob/main/docs/tutorials/getting_started.md) to import `intel_extension_for_pytorch` right after `import torch`, and prior to importing other packages.

### ⌨️   Hands on

1. [Login to Aurora](https://docs.alcf.anl.gov/aurora/getting-started-on-aurora/) and [submit an interactive job](https://docs.alcf.anl.gov/aurora/running-jobs-aurora#submitting-a-job):
   ```bash
   # 1. ssh into Aurora
   your-local-machine:$ ssh <your_alcf_username>@aurora.alcf.anl.gov 
   --------------------------------------------------------------
   Password:
   
   # 2. enter passcode (SafeNet MobilePass+ Mobile Token)
   # a shell opens on a login node
   
   # 3. submit an interactive job
   aurora-uan-0009:$ qsub -q debug -A <your_project_name> -l select=1,walltime=30:00 -l filesystems=home:flare -k doe -j oe -I
   
   # a shell opens on a compute node
   x4706c7s6b0n0:$
   ```

1. Load the `frameworks` module
   ```bash
   module load frameworks
   ```

1. Then, you can `import` PyTorch in Python as usual (below showing results from the `frameworks/2024.2.1_u1`  module):
   ```python
   >>> import torch
   >>> torch.__version__
   '2.3.1+cxx11.abi'
   ```

1. A simple but useful check could be to use PyTorch to get device information on a compute node. You can do this the following way:
   ```python
   import torch
   import intel_extension_for_pytorch as ipex
   
   print(f"GPU availability: {torch.xpu.is_available()}")
   print(f'Number of tiles = {torch.xpu.device_count()}')
   current_tile = torch.xpu.current_device()
   print(f'Current tile = {current_tile}')
   print(f'Current device ID = {torch.xpu.device(current_tile)}')
   print(f'Device properties = {torch.xpu.get_device_properties()}')
   ```

   Example output:
   ```python
   GPU availability: True
   Number of tiles = 12
   Current tile = 0
   Current device ID = <intel_extension_for_pytorch.xpu.device object at 0x1540a9f25790>
   Device properties = _XpuDeviceProperties(name='Intel(R) Data Center GPU Max 1550', platform_name='Intel(R) Level-Zero', \
   type='gpu', driver_version='1.3.30872', total_memory=65536MB, max_compute_units=448, gpu_eu_count=448, \
   gpu_subslice_count=56, max_work_group_size=1024, max_num_sub_groups=64, sub_group_sizes=[16 32], has_fp16=1, has_fp64=1, \
   has_atomic64=1)
   ```
   Each Aurora node has 6 GPUs (also called "Devices" or "cards") and each GPU is composed of two tiles (also called "Sub-device"). By default, each tile is mapped to one PyTorch device, giving a total of 12 devices per node in the above output. 

        

## Code changes to run PyTorch on Aurora GPUs

Here we list some common changes that you may need to do to your PyTorch code in order to use Intel GPUs.  

1. Import the `intel_extension_for_pytorch` **right after** importing `torch`:
   ```diff
   import torch
   + import intel_extension_for_pytorch as ipex
   ```
1. All the `API` calls involving `torch.cuda`, should be replaced with `torch.xpu`. For example:
   ```diff
   - torch.cuda.device_count()
   + torch.xpu.device_count()
   ```
1. When moving tensors and model to GPU, replace `"cuda"` with `"xpu"`. For example:
   ```diff
   - model = model.to("cuda")
   + model = model.to("xpu")
   ```
1. Convert model and loss criterion to `xpu`, and then call `ipex.optimize` for additional performance boost:
   ```python
   device = torch.device('xpu')
   model = model.to(device)
   criterion = criterion.to(device)
   model, optimizer = ipex.optimize(model, optimizer=optimizer)
   ```


### Example: training a PyTorch model on a single GPU tile

Here is a simple code to train a dummy PyTorch model on a single GPU tile on Aurora, where all code changes with respect to the CPU code are highlighted:

```diff
import torch
+ import intel_extension_for_pytorch as ipex
+ device = torch.device('xpu')

torch.manual_seed(0)

src = torch.rand((2048, 1, 512))
tgt = torch.rand((2048, 20, 512))
dataset = torch.utils.data.TensorDataset(src, tgt)
loader = torch.utils.data.DataLoader(dataset, batch_size=32, shuffle=True)

model = torch.nn.Transformer(batch_first=True)
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
criterion = torch.nn.CrossEntropyLoss()
model.train()
+ model = model.to(device)
+ criterion = criterion.to(device)
+ model, optimizer = ipex.optimize(model, optimizer=optimizer)

for epoch in range(10):
    for source, targets in loader:
+         source = source.to(device)
+         targets = targets.to(device)
        optimizer.zero_grad()

        output = model(source, targets)
        loss = criterion(output, targets)

        loss.backward()
        optimizer.step()
```

### ⌨️   Hands on

From a compute node of an interactive session:

1. Go into the directory `ALCFBeginnersGuide/Aurora-Getting-Started/aurora/examples/04_AI_frameworks/` of this repository, and change permissions to the script [`pytorch_xpu.py`](examples/04_AI_frameworks/pytorch_xpu.py) to make it executable:
   ```bash
   chmod a+x pytorch_xpu.py
   ```
1. [Load the frameworks module](https://docs.alcf.anl.gov/aurora/data-science/python#aiml-framework-module):
   ```bash
   module load frameworks
   ```
1. Run the script:
   ```bash
   python pytorch_xpu.py
   ```
1. You can interactively check the utilization of a given GPU on a compute node with the command:
   ```bash
   module load xpu-smi
   watch -n 0.1 xpu-smi stats -d <GPU_ID>
   ```


## Distributed Training on multiple GPUs

Distributed training with PyTorch on Aurora is facilitated through both [Distributed Data Parallel (DDP)](https://pytorch.org/tutorials/intermediate/ddp_tutorial.html) and [Horovod](https://horovod.readthedocs.io/en/stable/pytorch.html), with comparable performance. 
Here we show how to use native PyTorch DDP to perform Data Parallel training on Aurora. 


### Code changes to train on multiple GPUs using PyTorch Distributed Data Parallel (DDP)

The key steps in performing distributed training on Aurora are:

1. Load the `oneccl_bindings_for_pytorch` library, which enables efficient distributed deep learning training in PyTorch using [Intel's oneCCL library](https://github.com/intel/torch-ccl), implementing collectives like `allreduce`, `allgather`, `alltoall`.
1. Initialize PyTorch's `DistributedDataParallel`
1. Use `DistributedSampler` to partition the training data among the ranks
1. Pin each rank to a GPU
1. Wrap the model in DDP to keep it in sync across the ranks 
1. Rescale the learning rate
1. Use `set_epoch` for shuffling data across epochs


### Example: training a PyTorch model on a single GPU tile

Here is the code to train the [same dummy PyTorch model](#example-training-a-pytorch-model-on-a-single-gpu-tile) on multiple GPUs, where new or modified lines have been highlighted:

```diff
+ from mpi4py import MPI
+ import os, socket
import torch
+ from torch.nn.parallel import DistributedDataParallel as DDP
import intel_extension_for_pytorch as ipex
+ import oneccl_bindings_for_pytorch as torch_ccl

# DDP: Set environmental variables used by PyTorch
+ SIZE = MPI.COMM_WORLD.Get_size()
+ RANK = MPI.COMM_WORLD.Get_rank()
+ LOCAL_RANK = os.environ.get('PALS_LOCAL_RANKID')
+ os.environ['RANK'] = str(RANK)
+ os.environ['WORLD_SIZE'] = str(SIZE)
+ MASTER_ADDR = socket.gethostname() if RANK == 0 else None
+ MASTER_ADDR = MPI.COMM_WORLD.bcast(MASTER_ADDR, root=0)
+ os.environ['MASTER_ADDR'] = f"{MASTER_ADDR}.hsn.cm.aurora.alcf.anl.gov"
+ os.environ['MASTER_PORT'] = str(2345)
+ print(f"DDP: Hi from rank {RANK} of {SIZE} with local rank {LOCAL_RANK}. {MASTER_ADDR}")

# DDP: initialize distributed communication with nccl backend
+ torch.distributed.init_process_group(backend='ccl', init_method='env://', rank=int(RANK), world_size=int(SIZE))

# DDP: pin GPU to local rank.
+ torch.xpu.set_device(int(LOCAL_RANK))
device = torch.device('xpu')
torch.manual_seed(0)

src = torch.rand((2048, 1, 512))
tgt = torch.rand((2048, 20, 512))
dataset = torch.utils.data.TensorDataset(src, tgt)
# DDP: use DistributedSampler to partition the training data
+ sampler = torch.utils.data.distributed.DistributedSampler(dataset, shuffle=True, num_replicas=SIZE, rank=RANK, seed=0)
+ loader = torch.utils.data.DataLoader(dataset, sampler=sampler, batch_size=32)

model = torch.nn.Transformer(batch_first=True)
# DDP: scale learning rate by the number of GPUs.
+ optimizer = torch.optim.Adam(model.parameters(), lr=(0.001*SIZE))
criterion = torch.nn.CrossEntropyLoss()
model.train()
model = model.to(device)
criterion = criterion.to(device)
model, optimizer = ipex.optimize(model, optimizer=optimizer)
# DDP: wrap the model in DDP
+ model = DDP(model)

for epoch in range(10):
    # DDP: set epoch to sampler for shuffling
+     sampler.set_epoch(epoch)

    for source, targets in loader:
        source = source.to(device)
        targets = targets.to(device)
        optimizer.zero_grad()

        output = model(source, targets)
        loss = criterion(output, targets)

        loss.backward()
        optimizer.step()

# DDP: cleanup
+ torch.distributed.destroy_process_group()
```

### ⌨️   Hands on

Here are the steps to run the above code on Aurora:

1. [Login to Aurora](https://docs.alcf.anl.gov/aurora/getting-started-on-aurora/):
   ```bash
   ssh <username>@aurora.alcf.anl.gov
   ```
1. [Request an interactive job on two nodes](https://docs.alcf.anl.gov/aurora/running-jobs-aurora#submitting-a-job) for 30 minutes:
   ```bash
   qsub -q debug -A <your_project_name> -l select=2,walltime=30:00 -l filesystems=home:flare -k doe -j oe -I
   ```
1. Go into the directory `ALCFBeginnersGuide/Aurora-Getting-Started/aurora/examples/04_AI_frameworks/` of this repository, and change permissions to the script [`pytorch_ddp.py`](examples/04_AI_frameworks/pytorch_ddp.py) to make it executable with `chmod a+x pytorch_ddp.py`.
1. [Load the frameworks module](https://docs.alcf.anl.gov/aurora/data-science/python#aiml-framework-module):
   ```bash
   module load frameworks
   ```
1. Run the script on 24 tiles, 12 per node:
   ```bash
   mpiexec -n 24 -ppn 12 python pytorch_ddp.py
   ```


## Additional Resources

- [ALCF Docs: PyTorch on Aurora](https://docs.alcf.anl.gov/aurora/data-science/frameworks/pytorch/)
- [Intel's IPEX Documentation](https://intel.github.io/intel-extension-for-pytorch/xpu/latest/tutorials/examples.html)

# [NEXT ->](05_AI_training_at_scale.md)

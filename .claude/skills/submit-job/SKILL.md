---
name: submit-job
description: Submit a job to the Inspire cluster, wait for completion, and fetch logs. ONLY invoke this skill when the user explicitly asks to submit a job to Inspire (e.g. "submit the job", "submit to inspire", "launch on the cluster"). NEVER invoke this skill or any `inspire` CLI tools on your own initiative or as part of another task — regular training runs should be executed locally in the current environment, not submitted as cluster jobs.
argument-hint: [command] [--gpus N] [--type H200|H100] [--project P]
allowed-tools: Bash(inspire *)
---

Submit an Inspire training job and track it to completion with log retrieval.

## Arguments

$ARGUMENTS

## Critical: Cluster Environment Constraints

The cluster job environment differs significantly from a local dev machine. You MUST account for these constraints when constructing the `--command`:

### 1. Working directory is NOT the repo
The default working directory on the cluster node is NOT the user's repo. You MUST prefix every command with:
```bash
cd /inspire/hdd/global_user/wanjiaxin-253108030048/code/<repo-name> && source .venv/bin/activate &&
```
This ensures the command runs in the correct directory with the correct Python environment.

### 2. `uv` is NOT available on cluster nodes
Cluster images do not have `uv` installed. Do NOT use `uv run` in any part of the command chain — neither in the top-level command nor in any subprocess invoked by the training script. If the training script internally calls `uv run` (e.g., `uv run torchrun ...`), you must modify the script to call `torchrun` directly before submitting.

### 3. Cluster nodes have NO internet access
Cluster nodes cannot reach external networks. This means:
- **Set wandb to offline**: Always set `export WANDB_MODE=offline` in the command AND ensure the experiment manifest/JSON has `"enable_wandb": 1` and `"wandb_mode": "offline"`. The manifest values override environment variables via the ENV_KEY_MAP, so BOTH must be set. Using `offline` instead of `disabled` preserves logging locally; `disabled` removes the logger entirely and you lose all metrics.
- **No pip/uv install**: Packages cannot be installed on the fly. All dependencies must be pre-installed in the image or the `.venv`.
- **No huggingface-cli login**: Model downloads or auth-required API calls will fail.

### 4. Use the correct image
- Always use the latest version of the personal image (e.g., `dev-wjx` with the highest tag like `v2.1` > `v2.0`) with `--image-type SOURCE_PERSONAL_VISIBLE`, unless the user explicitly specifies a different image.
- Do NOT use official images (e.g., `ngc-pytorch:...`) — they lack the user's dependencies and `uv`/`venv` setup.
- Short image names work; no need for full Docker registry URLs.

## Workflow

### Step 1: Check GPU availability

Before submitting, always check the current cluster situation:
```bash
inspire resources allocate --gpus <N> --type <H200|H100>
```

This shows:
- Each compute group's `available` (idle GPUs), `low_pri` (GPUs running low-priority tasks, can be preempted), and `total`
- Tags: `[FREE]` = enough idle GPUs, `[PREEMPTIBLE]` = not enough idle GPUs, but low_pri count suggests preemption may work, `[QUEUED]` = not enough idle or preemptible GPUs, must queue and wait
- Each project's `priority` and `budget` (卡时) status — `EXHAUSTED` means no budget left

Based on this output, decide:
- **Which compute group** to use (`--location`) — prefer groups with `[FREE]` tag, then `[PREEMPTIBLE]` with most low_pri GPUs
- **Which project** to use (`--project`) — must have budget remaining; lower priority for free nodes, higher priority for preemption/queuing
- **What priority** to set (`--priority`) — low-pri tasks are typically priority 3. To preempt them, use the highest priority of your chosen project. For free nodes, use low priority; for queuing, higher priority means faster scheduling

### Step 2: Construct the command

Build the `--command` string following these rules:
```bash
cd /inspire/hdd/global_user/wanjiaxin-253108030048/code/<repo> && source .venv/bin/activate && export WANDB_MODE=offline && <actual_command>
```

Example for a Python training pipeline:
```bash
inspire job create -n "train-gpt" -r 8xH100 \
  -c "cd /inspire/hdd/global_user/wanjiaxin-253108030048/code/bag-of-tricks-transformers && source .venv/bin/activate && export WANDB_MODE=offline && python exp/run_experiments.py exp/geglu/geglu.json" \
  --location "cuda12.8版本H100" --project "公共兜底" --priority 3 \
  --image dev-wjx:v2.1 --image-type SOURCE_PERSONAL_VISIBLE
```

### Step 3: Submit the job

Use `inspire job create` with the `--location` chosen in Step 1. Do NOT rely on auto-selection (`inspire run`) — its location choice has no strong evidence (cannot see per-node task distribution).

Parameters:
- `-n`: auto-generate from the command content (e.g. "ablation-geglu")
- `-r` / `--resource`: GPU spec like `8xH200` or `8xH100`
- `-c`: the command from Step 2
- `--location`: the compute group name from Step 1 (e.g. `cuda12.8版本H100`)
- `--project` / `-p`: project name chosen from Step 1
- `--priority`: 1-10. Low-pri tasks are typically 3; to preempt them, use the chosen project's max priority
- `--image`: use the latest personal image (e.g. `dev-wjx` with highest tag), unless user specifies otherwise
- `--image-type`: `SOURCE_PERSONAL_VISIBLE`

If submission fails, report the error and stop.

### Step 4: Wait for completion

From the submission output, extract the job ID (from the line containing "Job created:").

Use `inspire job wait` to block until the job finishes:
```bash
inspire job wait <job-id>
```

Default timeout is 4 hours, poll interval 30 seconds. Override with `--timeout` and `--interval` if needed.

### Step 5: Fetch logs

Once the job finishes (or while it's running), fetch logs with:
```bash
inspire job logs <job-id>
```

**Important:** `inspire job logs` requires a running notebook to read the log file from the cluster's shared filesystem. It auto-discovers one, or specify with `--notebook`. If no notebook is available, logs can still be read directly from the shared filesystem path reported in the submission output, e.g.:
```bash
cat /inspire/hdd/global_user/wanjiaxin-253108030048/.inspire/training_master_*.log
```

Options:
- `--tail N` — show last N lines
- `--head N` — show first N lines
- `--follow` / `-f` — continuously stream new log output (like `tail -f`)
- `--refresh` — re-fetch from the beginning
- `--path` — just print the log file path

For a running job, `--follow` is the best way to track progress in real time.

### Step 6: Report

Report the final status and relevant log output. If the job failed, highlight error lines from the logs.

## Rules

- ONLY submit when the user explicitly asks to submit/run a training job. Never auto-submit on your own initiative.
- Always run `inspire resources allocate` before submitting — it provides the facts you need to make good decisions.
- Always specify `--location` explicitly based on allocate output. Do NOT use `inspire run` (its auto-selection lacks strong evidence).
- Keep the user informed but concise.
- Always use the latest personal image with `--image-type SOURCE_PERSONAL_VISIBLE`, unless the user specifies a different image.
- Always prefix commands with `cd <repo_path> && source .venv/bin/activate && export WANDB_MODE=offline &&`.
- Always ensure experiment manifests have `"enable_wandb": 1` and `"wandb_mode": "offline"` — manifest values override environment variables. Using `offline` preserves the logger; `disabled` removes it entirely.
- Never use `uv run` in commands or in scripts called by the command — `uv` is not available on cluster nodes.

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `uv: command not found` | `uv` not installed in cluster image | Use `source .venv/bin/activate` instead of `uv run` |
| `.venv/bin/activate: No such file or directory` | Working directory is not the repo | Prefix command with `cd /inspire/.../repo &&` |
| `wandb.errors.errors.UsageError: No API key configured` | Cluster has no internet; wandb tries to log in | Set `WANDB_MODE=offline` AND fix manifest to `enable_wandb: 1, wandb_mode: offline` |
| `image not found` when using short image name | Wrong `--image-type` flag | Use `--image-type SOURCE_PERSONAL_VISIBLE` for personal images |

## Quick Reference

| Command | Purpose |
|---------|---------|
| `inspire resources allocate -g 8 --type H100` | Check GPU availability & project budget |
| `inspire job create -n NAME -r 8xH100 -c "cmd" --location LOC -p PROJ --priority N --image dev-wjx:<latest> --image-type SOURCE_PERSONAL_VISIBLE` | Submit a job |
| `inspire job wait JOB_ID` | Block until job finishes |
| `inspire job logs JOB_ID` | Fetch job logs |
| `inspire job logs JOB_ID -f --tail 50` | Stream last 50 lines and follow |
| `inspire job status JOB_ID` | Check current status |
| `inspire job stop JOB_ID` | Stop a running/pending job |
| `inspire job list` | List all jobs |
| `cat /inspire/hdd/.../.inspire/training_master_*.log` | Read log directly from shared filesystem |


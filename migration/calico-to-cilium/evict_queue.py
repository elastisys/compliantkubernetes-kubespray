#!/usr/bin/env python3
"""
Queue-based pod eviction.

If an unevictable pod is encountered, it is thrown to the back of the queue,
so the remaining evictions can continue.
"""
import random
import subprocess
import sys
import time
from collections import deque
from datetime import datetime

MAX_ATTEMPTS: int = 60
WAIT_TIME: float = 10.0


def yellow_text(what: str) -> str:
    return f"\033[93m{what}\033[0m"


def blue_text(what: str) -> str:
    return f"\033[34m{what}\033[0m"


def log_info(what: str) -> None:
    print(f"\n[{blue_text('calico-to-cilium')}] {what}", file=sys.stderr)


def main(pods: list[str]) -> int:
    # Do an initial shuffle so we lower the disruption chance of non-HA workloads.
    random.shuffle(pods)
    queue = deque([(pod, 1, datetime.now()) for pod in pods])

    ret = 0

    while queue:
        pod, attempts, queue_time = queue.popleft()

        if attempts >= MAX_ATTEMPTS:
            ret = 1

        if attempts > 1:
            if (chill_time := WAIT_TIME - (datetime.now() - queue_time).total_seconds()) > 0:
                time.sleep(chill_time)

        pod_ns, pod_name = pod.split("/")[:2]

        phase = kubectl(f"get pod --namespace {pod_ns} {pod_name} -o jsonpath={{.status.phase}}")

        # Yes, we evict 'Pending' pods, because in the phase world this means
        # 'one or more of the containers has not been started', and we do want to catch
        # newly spawned pods.
        #
        # See https://github.com/kubernetes/kubernetes/blob/v1.32.8/pkg/apis/core/types.go#L2919
        if phase == "Running" or phase == "Pending":
            log_info(f"Evicting pod {yellow_text(pod)} [{attempts}/{MAX_ATTEMPTS}]")
            if kubectl(f"evict --namespace {pod_ns} {pod_name}") is None:
                queue.append((pod, attempts + 1, datetime.now()))

    return ret


def kubectl(cmd: str) -> str | None:
    try:
        return str(subprocess.check_output(f"kubectl {cmd}".split(), text=True))
    except subprocess.CalledProcessError:
        return None


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

Conformance tests for bare metal machines.

- `conformance-test.bash` - Test script that should be run on the target machine. Tests that the machine is ready to be used as a node in a ck8s cluster.
- `conformance-test-remote.bash` - Script that can be used to run the test script remotely. Run with `./conformance-test-remote.bash USERNAME IP` (username and IP of the target machine)
#!/usr/bin/env bash
# Container entry point: runs the given command (default: bash) in the repository.
# Afterwards, files under results/ are given the owner of the results/ directory,
# so results in a directory mounted from the host belong to the host user.
cd /artifact/Pact-Experiments
mkdir -p results
"$@"
rc=$?
chown -R "$(stat -c %u:%g results)" results 2>/dev/null
exit $rc

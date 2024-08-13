#!/bin/bash 
#
# This wrapper is used to handle signals from the GitHub Actions runner to allow terraform to gracefully shutdown:
# 1. Start the terraform process and pass any arguments to it
# 2. Catch any signals sent by the GitHub Actions runner
# 3. Pass a SIGTERM signal to the terraform process
# 4. Wait for the terraform process to finish while ignoring additional signals sent by the GitHub Actions runner.
# Example call:
# - run: exec terraform.sh apply -auto-approve
#
# - Script based on this discussion - Graceful job termination #26311: https://github.com/orgs/community/discussions/26311
#   - Use exec to force a single parent process to be spawned
#   - When using the terraform action to install terraform, terraform_wrapper must be disabled.
# - Github actions gives the current process 10 seconds to shutdown before force killing it.
#   - Cancelling a workflow: https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/canceling-a-workflow
#   - SIGTERM kills the job instead of waiting for job completion: https://github.com/actions/runner/issues/3308

trap '_handle_signal $?' SIGTERM SIGINT SIGHUP SIGUSR1 SIGUSR2 SIGABRT SIGQUIT SIGPIPE SIGALRM SIGTSTP SIGTTIN SIGTTOU

COUNTER=0
_handle_signal() { 
  local signal=$1
  echo "Caught signal: $signal"

  if ((COUNTER < 1))
  then
    echo "Passing SIGTERM signal to terraform process."
    kill -SIGTERM "$child" 2>&1
  else
    echo "Terraform is already shutting down. Allow the process to complete so state changes can be saved."
  fi

  ((COUNTER++))
}

terraform "$@" &
child=$!
wait "$child"

#!/bin/bash
#
# This wrapper is used to handle signals from the GitHub Actions runner to allow terraform to gracefully shutdown:
# 1. Start the terraform process and pass any arguments to it
# 2. Catch any signals sent by the GitHub Actions runner
# 3. Pass a SIGTERM signal to the terraform process
# 4. Wait for the terraform process to finish while ignoring additional signals sent by the GitHub Actions runner.
# 5. Use a post action to check if the process is still running and decide if a force kill/second signal is needed.
#   - Github actions will force kill the action after 10 seconds.
#   - After the initial signal is sent, the default timeout is 5 minutes and can be extended with the cancel-timeout-minutes key.
# Example call:
# - run: exec terraform.sh apply -auto-approve
#
# Outputs will can be used to check if the process is up and if we need to cancel it.
# Outputs to GITHUB_STATE (post-action environment variables) and GITHUB_OUTPUT (action step outputs):
# - state values are prepended with 'STATE_' by the runner and only available in the paired post action.
# - TERRAFORM_STATUS: START | PROVISIONING | PROVISIONED | STOPPING | STOPPED | DESTROYING | DESTROYED | ERROR
# - TERRAFORM_PID: The PID of the terraform process.
#  - 'wait' will not work across action steps since a new shell is spawned for each step.
#    - tmux | screen | tmate - virtual terminals that can be used to keep the process running and recover it later.
#    - reptyr | screenify | ptrace | gdb - tools that can be used to reattach to a running process but requires a tty.
#
# - Script based on this discussion - Graceful job termination #26311: https://github.com/orgs/community/discussions/26311
#   - Use 'exec' to force a shell to run the script as the main process.
#   - When using the terraform action to install terraform, terraform_wrapper must be disabled.
#   - https://github.com/actions/toolkit/issues/1534
# - Github actions gives the current process 10 seconds to shutdown before force killing it.
#   - Use `cancel-timeout-minutes` at the workflow level to set the timeout limit for all workflow actions and composite actions that run after the inital process is cancelled.
#   - Cancelling a workflow: https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/canceling-a-workflow
#   - SIGTERM kills the job instead of waiting for job completion: https://github.com/actions/runner/issues/3308

COUNTER=0
TERRAFORM_STATUS=${TERRAFORM_STATUS:-"START"}
TERRAFORM_PID=""
_handle_signal() {
  local signal=$1
  echo "Caught signal: $signal"

  if ((COUNTER < 1))
  then
    echo "Passing SIGTERM signal to terraform process."
    TERRAFORM_STATUS="STOPPING"
    echo "TERRAFORM_STATUS=$TERRAFORM_STATUS" | tee -a $GITHUB_STATE $GITHUB_OUTPUT $GITHUB_ENV
    kill -SIGTERM "$child" 2>&1
    echo "Signal sent and additional signals will be ignored."
    echo "A post step should be used to check if the process is still running and decide if a force kill/second signal is needed."
    echo "Github actions will force kill the action after 10 seconds. After the initial step is stopped, all steps will be skipped once the cancel-timeout-minutes (5 minute default) limit is reached."
  else
    echo "Terraform is already shutting down. Allow the process to complete so state changes can be saved."
  fi

  ((COUNTER++))
}
trap '_handle_signal $?' SIGTERM SIGINT SIGHUP SIGUSR1 SIGUSR2 SIGABRT SIGQUIT SIGPIPE SIGALRM SIGTSTP SIGTTIN SIGTTOU

ACTION=$1
case "$ACTION" in
  apply)
    TERRAFORM_STATUS="PROVISIONING"
    ;;
  destroy)
    TERRAFORM_STATUS="DESTROYING"
    ;;
  *)
    echo "Invalid terraform command: $1"
    exit 1
    ;;
esac
echo "TERRAFORM_STATUS=$TERRAFORM_STATUS" | tee -a $GITHUB_STATE $GITHUB_OUTPUT $GITHUB_ENV

terraform "$@" &
child=$!
echo "TERRAFORM_PID=$child" | tee -a $GITHUB_STATE $GITHUB_OUTPUT $GITHUB_ENV
wait "$child"
RC=$?
if [ "$TERRAFORM_STATUS" == "STOPPING" ] || (( "$RC" != 0 ))
then
  [ "$TERRAFORM_STATUS" != "STOPPING" ] && echo "TERRAFORM_STATUS=ERROR" | tee -a $GITHUB_STATE $GITHUB_OUTPUT $GITHUB_ENV
  echo "Terraform process encounted an issue: $TERRAFORM_STATUS"
  exit $RC
fi

case "$ACTION" in
  apply)
    echo "TERRAFORM_STATUS=PROVISIONED" | tee -a $GITHUB_STATE $GITHUB_OUTPUT $GITHUB_ENV
    ;;
  destroy)
    echo "TERRAFORM_STATUS=DESTROYED" | tee -a $GITHUB_STATE $GITHUB_OUTPUT $GITHUB_ENV
    ;;
esac
echo "Terraform process has completed."

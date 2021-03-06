class Api::V1::DayTasksController < Api::V1::ApiController
  inherit_resources

  belongs_to :day

  load_and_authorize_resource :user

  def day_task_params
    params.require(:day_task).permit(:task_id)
  end
end

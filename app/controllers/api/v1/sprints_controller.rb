class Api::V1::SprintsController < Api::V1::ApiController
  inherit_resources

  load_and_authorize_resource through: :current_user

  def index
    sprints = paginate current_user.sprints.order(start_date: :desc)

    render json: sprints.as_json({ include: {} })
  end

  private

  def sprint_params
    params.require(:sprint).permit(:name, :start_date, :end_date).merge(user_id: current_user.id)
  end
end

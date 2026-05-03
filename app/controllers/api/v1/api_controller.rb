class Api::V1::ApiController < ApplicationController
  include Rails::Pagination

  respond_to :json

  before_action :set_default_response_format
  before_action :set_default_response_headers

  helper_method :current_user, :logged_in?

  skip_before_action :verify_authenticity_token

  protected

  def current_user
    unless @current_user
      key = request.headers['X-Qer-Authorization'] || params[:_key] || cookies[:api_key]
      if key.blank?
        raise ApiKeyNotFound
      end

      @current_user = User.where(:api_key => key).first
      unless @current_user
        raise ApiKeyInvalid
      end
    end
    @current_user
  end

  def logged_in?
    !!current_user
  end

  def set_default_response_format
    request.format = 'json' if params[:format].blank?
  end

  def set_default_response_headers
    response.headers['Cache-Control'] = 'no-cache, no-store'
  end

  rescue_from CanCan::AccessDenied do |exception|
    render json: { errors: exception.message }, status: :unauthorized
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { errors: exception.message }, status: :unauthorized
  end

  def load_index_from_nested_resource(parent, association)
    res = nil

    res.send(association)
    rescue ActiveRecord::RecordNotFound
      raise CanCan::AccessDenied.new("Not authorized to access members of that #{parent}")
    end

  class ApiKeyNotFound < CanCan::AccessDenied
    def initialize(msg = "API key not found")
      super(msg)
    end
  end

  class ApiKeyInvalid < CanCan::AccessDenied
    def initialize(msg = "API key is invalid")
      super(msg)
    end
  end
end

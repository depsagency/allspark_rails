module ApiAuthenticatable
  extend ActiveSupport::Concern
  
  included do
    before_action :authenticate_api_user!
  end
  
  private
  
  def authenticate_api_user!
    # First try standard session authentication
    return if user_signed_in?
    
    # Then try API token authentication
    authenticate_with_api_token
  end
  
  def authenticate_with_api_token
    token = extract_api_token
    
    return render_unauthorized unless token.present?
    
    # In a real implementation, you'd want to use a proper API token model
    # For now, we'll use a simple approach with user tokens
    user = User.find_by(api_token: token) if defined?(User.api_token)
    
    if user
      sign_in(user, store: false)
    else
      render_unauthorized
    end
  end
  
  def extract_api_token
    # Extract token from Authorization header
    if request.headers['Authorization'].present?
      request.headers['Authorization'].split(' ').last
    else
      params[:api_token]
    end
  end
  
  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
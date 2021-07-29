class SimpleController::Responder < ActionController::Responder
  include Responders::FlashResponder
  # include Responders::HttpCacheResponder

  def json_resource_errors
    { errors: resource.errors, message: resource.errors.map { |error| error.message}.join('\n') }
  end
end

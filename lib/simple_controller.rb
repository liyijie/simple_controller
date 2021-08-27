require 'rails'
require 'active_record'

require 'responders'
require 'ransack'
require 'inherited_resources'
require 'pundit'

module SimpleController
  autoload :VERSION,            'simple_controller/version'
  autoload :BaseController,               'simple_controller/base_controller'
  autoload :Exportable,               'simple_controller/exportable'
  autoload :Importable,               'simple_controller/importable'
  autoload :Responder,               'simple_controller/responder'
end

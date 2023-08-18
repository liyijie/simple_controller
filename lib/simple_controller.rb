require 'rails'
require 'active_record'

require 'responders'
require 'ransack'
require 'inherited_resources'
require 'pundit'
require 'ransack_mongo'

module SimpleController
  autoload :VERSION,                  'simple_controller/version'
  autoload :BaseController,           'simple_controller/base_controller'
  autoload :Exportable,               'simple_controller/exportable'
  autoload :Importable,               'simple_controller/importable'
  autoload :GroupIndex,               'simple_controller/group_index'
  autoload :Responder,                'simple_controller/responder'
end

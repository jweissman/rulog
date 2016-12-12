require 'rspec'
require 'pry'
require 'rulog/version'

include Rulog
RSpec.configure { |c| c.disable_monkey_patching! }

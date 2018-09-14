# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ecpay_invoice/version'

Gem::Specification.new do |spec|
  spec.name          = "ecpay_invoice"
  spec.version       = ECpayInvoice::VERSION
  spec.authors       = ["Ying Wu"]
  spec.email         = ["ying.wu@ecpay.com.tw"]

  spec.summary       = "綠界電子發票串接用SDK"
  spec.description   = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 11.1"
  spec.add_development_dependency "rspec", "~> 3.4"
end

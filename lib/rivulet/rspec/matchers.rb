require 'rspec'

RSpec::Matchers.define :have_http_status do |status|
  match do |response|
    response.status == status
  end

  failure_message do
    "expected response to have http status #{status} but got #{response.status}"
  end

  failure_message_when_negated do
    "expected response not to have http status #{status}"
  end
end

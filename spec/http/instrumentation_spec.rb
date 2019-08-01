# frozen_string_literal: true

RSpec.describe HTTP::Instrumentation do
  it 'has a version number' do
    expect(HTTP::Instrumentation::VERSION).not_to be nil
  end
end

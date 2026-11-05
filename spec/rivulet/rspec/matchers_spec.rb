RSpec.describe 'Rivulet::RSpec::Matchers' do
  describe 'have_http_status' do
    let(:response) do
      Rack::MockResponse.new(response_code, {}, "")
    end

    context 'with matching status code' do
      let(:response_code) { 200 }

      it 'passes' do
        expect(response).to have_http_status(response_code)
      end
    end

    context 'with mismatched status code' do
      let(:response_code) { 200 }
      let(:expected_code) { 404 }

      it 'provides failure message for to' do
        matcher = have_http_status(expected_code)

        expect(matcher.matches?(response)).to eq false
        expect(matcher.failure_message)
          .to eq("expected response to have http status #{expected_code} but got #{response_code}")
      end

      it 'provides failure message for not_to' do
        expect {
          expect(response).not_to have_http_status(response_code)
        }.to raise_error(
          RSpec::Expectations::ExpectationNotMetError,
          "expected response not to have http status #{response_code}"
        )
      end
    end
  end
end

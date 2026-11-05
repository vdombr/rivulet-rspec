RSpec.describe Rivulet::RSpec::Helpers do
  let(:envs) { [] }
  let(:triple) { [200, { 'Content-Type' => 'application/json' }, ['{"ok":true}']] }

  subject(:client) do
    helpers = described_class
    Class.new { include helpers }.new
  end

  before do
    Rivulet.app = lambda do |env|
      envs << env
      triple
    end
  end

  def last_request
    Rack::Request.new(envs.last)
  end

  shared_examples_for 'an http verb' do |verb|
    before { @verb = verb }

    def perform(url, **kwargs)
      client.send(@verb, url, **kwargs)
    end

    it "sends a #{verb.to_s.upcase} request to the given path" do
      perform('/users')

      expect(last_request.request_method).to eq(verb.to_s.upcase)
      expect(last_request.path_info).to eq('/users')
    end

    it 'serializes params as a JSON body by default' do
      perform('/users', params: { name: 'a', n: 1 })
      request = last_request

      expect(request.content_type).to eq('application/json')
      expect(Oj.load(request.body.read)).to eq({ 'name' => 'a', 'n' => 1 })
    end

    it 'sends an empty JSON body when no params are given' do
      perform('/users')
      request = last_request

      expect(request.content_type).to eq('application/json')
      expect(request.body.read).to eq('{}')
    end

    it 'treats text/json as JSON too' do
      perform('/users', params: { name: 'a' }, content_type: 'text/json')
      request = last_request

      expect(request.content_type).to eq('text/json')
      expect(Oj.load(request.body.read)).to eq({ 'name' => 'a' })
    end

    it 'form-encodes params for urlencoded content type' do
      perform('/users', params: { name: 'a b', n: '1' }, content_type: 'application/x-www-form-urlencoded')

      expect(last_request.params).to eq('name' => 'a b', 'n' => '1')
    end

    it 'rejects plain hash params for multipart/form-data' do
      expect do
        perform('/users', params: { a: '1' }, content_type: 'multipart/form-data')
      end.to raise_error(ArgumentError, /multipart/)

      expect(envs).to be_empty
    end

    it 'passes String bodies through for other content types' do
      perform('/users', params: '<a/>', content_type: 'application/xml')
      request = last_request

      expect(request.content_type).to eq('application/xml')
      expect(request.body.read).to eq('<a/>')
    end

    it 'rejects hash params for other content types' do
      expect do
        perform('/users', params: { name: 'a' }, content_type: 'application/xml')
      end.to raise_error(ArgumentError, /cannot encode Hash/)
    end

    it 'maps headers onto the request' do
      perform('/users', headers: { Authorization: 'Bearer t' })

      expect(last_request.env['HTTP_AUTHORIZATION']).to eq('Bearer t')
    end

    it 'forwards the app response' do
      perform('/users')

      expect(client.response.status).to eq(200)
      expect(client.response.body).to eq('{"ok":true}')
    end
  end

  describe 'get' do
    it 'sends a GET request to the given path' do
      client.get('/users')

      expect(last_request.request_method).to eq('GET')
      expect(last_request.path_info).to eq('/users')
    end

    it 'passes query params through' do
      client.get('/users', params: { q: 'a b&c' })

      expect(last_request.params).to eq('q' => 'a b&c')
    end

    it 'passes multi-value params through' do
      client.get('/users', params: { tags: %w[x y] })

      expect(last_request.params['tags']).to eq(%w[x y])
    end

    it 'sends no params by default' do
      client.get('/users')

      expect(last_request.params).to eq({})
    end

    it 'merges the URL query with params, URI winning on key collision' do
      client.get('/users?active=1', params: { 'active' => '0', q: 'x' })

      expect(last_request.params).to eq('active' => '1', 'q' => 'x')
    end

    it 'maps headers onto the request' do
      client.get('/users', headers: { Authorization: 'Bearer t' })

      expect(last_request.env['HTTP_AUTHORIZATION']).to eq('Bearer t')
    end

    it 'normalizes dashed and underscored header keys alike' do
      client.get('/users', headers: { 'X-Custom-Id': '1' })
      expect(last_request.env['HTTP_X_CUSTOM_ID']).to eq('1')

      client.get('/users', headers: { x_custom_id: '2' })
      expect(last_request.env['HTTP_X_CUSTOM_ID']).to eq('2')
    end

    it 'sends no HTTP_ headers by default' do
      client.get('/users')

      expect(last_request.env.select { |key, _| key.start_with?('HTTP_') }).to be_empty
    end

    context 'when the app responds with a non-default triple' do
      let(:triple) { [201, { 'Location' => '/u/9' }, ['created']] }

      it 'forwards status, headers and body into response' do
        client.get('/users')

        expect(client.response.status).to eq(201)
        expect(client.response.headers['location']).to eq('/u/9')
        expect(client.response.body).to eq('created')
      end
    end

    it 'exposes the app triple as a Rack::MockResponse' do
      client.get('/users')

      expect(client.response).to be_a(Rack::MockResponse)
      expect(client.response.ok?).to be(true)
    end
  end

  describe 'post' do
    include_examples 'an http verb', :post
  end

  describe 'put' do
    include_examples 'an http verb', :put
  end

  describe 'patch' do
    include_examples 'an http verb', :patch
  end

  describe 'delete' do
    include_examples 'an http verb', :delete
  end

  describe 'response' do
    it 'is nil before any request' do
      expect(client.response).to be_nil
    end

    it 'returns the app response after a request' do
      client.get('/users')

      expect(client.response.status).to eq(200)
      expect(client.response.headers['content-type']).to eq('application/json')
      expect(client.response.body).to eq('{"ok":true}')
    end

    it 'keeps only the most recent response' do
      Rivulet.app = ->(_env) { [201, {}, ['first']] }
      client.get('/users')
      expect(client.response.body).to eq('first')

      Rivulet.app = ->(_env) { [204, {}, []] }
      client.post('/users')
      expect(client.response.status).to eq(204)
      expect(client.response.body).to eq('')
    end

    it 'returns the same object on repeated calls' do
      client.get('/users')

      expect(client.response).to equal(client.response)
    end
  end

  describe 'json_response' do
    context 'with a nested object body' do
      let(:triple) { [200, {}, ['{"user":{"id":1,"name":"x"},"items":[{"id":2}],"count":3,"ok":true,"note":null}']] }

      it 'deep-symbolizes hash keys' do
        client.get('/data')

        expect(client.json_response).to eq(
          user: { id: 1, name: 'x' },
          # The spec-local deep_symbolize_keys (see spec_helper) does not
          # recurse into arrays, so hashes inside arrays keep string keys
          items: [{ 'id' => 2 }],
          count: 3, ok: true, note: nil
        )
      end
    end

    context 'with an empty object body' do
      let(:triple) { [200, {}, ['{}']] }

      it 'returns an empty hash' do
        client.get('/data')

        expect(client.json_response).to eq({})
      end
    end

    context 'with a top-level array body' do
      let(:triple) { [200, {}, ['[]']] }

      it 'raises ArgumentError instead of NoMethodError' do
        client.get('/data')

        expect { client.json_response }.to raise_error(ArgumentError, /expected a JSON object.*got Array/)
      end
    end

    context 'with top-level scalar bodies' do
      it 'raises ArgumentError for a string payload' do
        Rivulet.app = ->(_env) { [200, {}, ['"hi"']] }
        client.get('/data')

        expect { client.json_response }.to raise_error(ArgumentError, /got String/)
      end

      it 'raises ArgumentError for a numeric payload' do
        Rivulet.app = ->(_env) { [200, {}, ['42']] }
        client.get('/data')

        expect { client.json_response }.to raise_error(ArgumentError, /got Integer/)
      end
    end

    context 'with an invalid JSON body' do
      let(:triple) { [200, {}, ['<xml/>']] }

      it 'raises Oj::ParseError' do
        client.get('/data')

        expect { client.json_response }.to raise_error(Oj::ParseError)
      end
    end

    context 'with an empty body' do
      let(:triple) { [200, {}, ['']] }

      it 'raises ArgumentError (Oj.load("") returns nil)' do
        client.get('/data')

        expect { client.json_response }.to raise_error(ArgumentError, /got NilClass/)
      end
    end

    context 'across multiple requests' do
      it 'reflects the most recent response' do
        Rivulet.app = ->(_env) { [200, {}, ['{"a":1}']] }
        client.get('/one')
        expect(client.json_response).to eq(a: 1)

        Rivulet.app = ->(_env) { [200, {}, ['{"b":2}']] }
        client.post('/two')
        expect(client.json_response).to eq(b: 2)
      end
    end
  end

  describe 'error handling' do
    it 'propagates errors raised by the app unchanged' do
      Rivulet.app = ->(_env) { raise ArgumentError, 'boom' }

      expect { client.get('/users') }.to raise_error(ArgumentError, 'boom')
      expect(client.response).to be_nil
    end
  end
end

module Nem
  module Endpoint
    module Local
      # @return [Array <Nem::Model::ExpelorerBlock>]
      # @see https://nemproject.github.io/#getting-part-of-a-chain
      class Chain < Nem::Endpoint::Base
        def blocks_after(height)
          request!(:post, '/local/chain/blocks-after', height: height) do |res|
            res[:data].map do |data|
              Nem::Model::ExpelorerBlock.new_from_explorer_block(data)
            end
          end
        end
      end
    end
  end
end

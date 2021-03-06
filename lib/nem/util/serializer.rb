module Nem
  module Util
    module Serializer
      # Serialize a transaction object
      # @param [Hash] entity
      # @return [Array]
      def self.serialize_transaction(entity)
        specific = case entity[:type]
                   when 0x0101 then serialize_transfer(entity)
                   when 0x0801 then serialize_importance_transfer(entity)
                   when 0x1001 then serialize_multisig_aggregate_modification(entity)
                   when 0x1002 then serialize_multisig_signature(entity)
                   when 0x1004 then serialize_multisig(entity)
                   when 0x2001 then serialize_provision_namespace(entity)
                   when 0x4001 then serialize_mosaic_definition_creation(entity)
                   when 0x4002 then serialize_mosaic_supply_change(entity)
          else raise "Not implemented entity type: #{entity[:type]}"
        end
        serialize_common(entity) + specific
      end

      private

      def self.serialize_transfer(entity)
        a = []
        a.concat serialize_safe_string(entity[:recipient])
        a.concat serialize_long(entity[:amount])
        payload = Nem::Util::Convert.hex2ua(entity[:message][:payload])
        if payload.size == 0
          a.concat [0, 0, 0, 0]
        else
          a.concat serialize_int(payload.size + 8)
          a.concat serialize_int(entity[:message][:type])
          a.concat serialize_int(payload.size)
          a.concat payload
        end
        if entity[:mosaics] && entity[:mosaics].size > 0
          a.concat serialize_mosaics(entity[:mosaics])
        end
        a
      end

      def self.serialize_importance_transfer(entity)
        a = []
        a.concat serialize_int(entity[:mode])
        temp = Nem::Util::Convert.hex2ua(entity[:remoteAccount])
        a.concat serialize_int(temp.size)
        a.concat temp
      end

      def self.serialize_multisig_aggregate_modification(entity)
        a = []
        a.concat serialize_int(entity[:modifications].size)
        mods = entity[:modifications].inject([]) do |b, mod|
          b.concat serialize_int(40)
          b.concat serialize_int(mod[:modificationType])
          b.concat serialize_int(32)
          b.concat Nem::Util::Convert.hex2ua(mod[:cosignatoryAccount])
          b
        end
        a.concat mods

        if true # TODO: append only version2
          a.concat serialize_int(4)
          a.concat serialize_int(entity[:minCosignatories][:relativeChange])
        end
        a
      end

      def self.serialize_multisig_signature(entity)
        a = []
        temp = Nem::Util::Convert.hex2ua(entity[:otherHash][:data])
        a.concat serialize_int(4 + temp.size)
        a.concat serialize_int(temp.size)
        a.concat temp
        a.concat serialize_safe_string(entity[:otherAccount])
      end

      def self.serialize_multisig(entity)
        a = []
        trans = entity[:otherTrans]
        tx = case trans[:type]
             when 0x0101 then serialize_transfer(trans)
             when 0x0801 then serialize_importance_transfer(trans)
             when 0x1001 then serialize_multisig_aggregate_modification(trans)
             when 0x2001 then serialize_provision_namespace(trans)
             when 0x4001 then serialize_mosaic_definition_creation(entity)
             when 0x4002 then serialize_mosaic_supply_change(entity)
          else raise "Unexpected type #{trans[:type]}"
        end
        tx = serialize_common(trans) + tx
        a.concat serialize_int(tx.size)
        a.concat tx
      end

      def self.serialize_provision_namespace(entity)
        a = []
        a.concat serialize_safe_string(entity[:rentalFeeSink])
        a.concat serialize_long(entity[:rentalFee])
        temp = Nem::Util::Convert.hex2ua(Nem::Util::Convert.utf8_to_hex(entity[:newPart]))
        a.concat serialize_int(temp.size)
        a.concat temp
        if entity[:parent]
          temp = Nem::Util::Convert.hex2ua(Nem::Util::Convert.utf8_to_hex(entity[:parent]))
          a.concat serialize_int(temp.size)
          a.concat temp
        else
          a.concat [255, 255, 255, 255]
        end
        a
      end

      def self.serialize_mosaic_definition_creation(entity)
        a = []
        a.concat serialize_mosaic_definition(entity[:mosaicDefinition])
        a.concat serialize_safe_string(entity[:creationFeeSink])
        a.concat serialize_long(entity[:creationFee])
      end

      def self.serialize_mosaic_supply_change(entity)
        a = []
        a.concat serialize_mosaic_id(entity[:mosaicId])
        a.concat serialize_int(entity[:supplyType])
        a.concat serialize_long(entity[:delta])
      end

      def self.serialize_common(entity)
        a = []
        a.concat serialize_int(entity[:type])
        a.concat serialize_int(entity[:version])
        a.concat serialize_int(entity[:timeStamp])

        signer = Nem::Util::Convert.hex2ua(entity[:signer])
        a.concat serialize_int(signer.size)
        a.concat signer

        a.concat serialize_long(entity[:fee].to_i)
        a.concat serialize_int(entity[:deadline])
      end

      # Safe String - Each char is 8 bit
      # @param [String] str
      # @return [Array]
      def self.serialize_safe_string(str)
        return [255, 255, 255, 255] if str.nil?
        return [0, 0, 0, 0] if str.empty?
        [str.size, 0, 0, 0] + str.bytes
      end

      # @param [String] str
      # @return [Array]
      def self.serialize_bin_string(str)
        return [255, 255, 255, 255] if str.nil?
        return [0, 0, 0, 0] if str.empty?
        chars = str.is_a?(String) ? str.chars : str
        [chars.size, 0, 0, 0] + chars.map(&:to_i)
      end

      # @param [Integer] value
      # @return [Array]
      def self.serialize_int(value)
        [value].pack('I').unpack('C4')
      end

      # @param [Integer] value
      # @return [Array]
      def self.serialize_long(value)
        [value].pack('Q').unpack('C8').map { |n| n < 0 ? 256 + n : n }
      end

      # @param [Nem::Struct::Mosaic] mosaic
      # @return [Array]
      def self.serialize_mosaic_attachment(mosaic_attachment)
        a = []
        mosaic_id = serialize_mosaic_id(mosaic_attachment[:mosaicId])
        quantity = serialize_long(mosaic_attachment[:quantity])
        a.concat serialize_int((mosaic_id + quantity).size)
        a.concat mosaic_id
        a.concat quantity
      end

      # @param [Array <Nem::Struct::Mosaic>] entities
      # @return [Array]
      def self.serialize_mosaics(entities)
        a = []
        a.concat serialize_int(entities.size)
        mosaics = entities.inject([]) do |memo, ent|
          memo.concat serialize_mosaic_attachment(ent)
        end
        a.concat mosaics
      end

      # @param [Hash] entity
      # @return [Array]
      def self.serialize_mosaic_id(entity)
        a = []
        a.concat serialize_safe_string(entity[:namespaceId])
        a.concat serialize_safe_string(entity[:name])
        serialize_int(a.size) + a
      end

      # @param [Hash] entity
      # @return [Array]
      def self.serialize_property(entity)
        a = []
        a.concat serialize_safe_string(entity[:name])
        a.concat serialize_safe_string(entity[:value])
        serialize_int(a.size) + a
      end

      # @param [Array] entities
      # @return [Array]
      def self.serialize_properties(entities)
        order = {
          'divisibility'  => 1,
          'initialSupply' => 2,
          'supplyMutable' => 3,
          'transferable'  => 4
        }
        serialize_int(entities.size) + entities
          .sort_by { |ent| order[ent[:name]] }
          .inject([]) { |memo, ent| memo + serialize_property(ent) }
      end

      # @param [Hash] entity
      # @return [Array]
      def self.serialize_levy(entity)
        return [0, 0, 0, 0] if entity.nil?
        a = []
        a.concat serialize_int(entity[:type])
        a.concat serialize_safe_string(entity[:recipient])
        a.concat serialize_mosaic_id(entity[:mosaicId])
        a.concat serialize_long(entity[:fee])
        serialize_int(a.size) + a
      end

      # @param [Hash] entity
      # @return [Array]
      def self.serialize_mosaic_definition(entity)
        a = []
        creator = Nem::Util::Convert.hex2ua(entity[:creator])
        a.concat serialize_int(creator.size)
        a.concat creator
        a.concat serialize_mosaic_id(entity[:id])
        a.concat serialize_bin_string(Nem::Util::Convert.hex2ua(Nem::Util::Convert.utf8_to_hex(entity[:description])))
        a.concat serialize_properties(entity[:properties])
        a.concat serialize_levy(entity[:levy])
        serialize_int(a.size) + a
      end
    end
  end
end

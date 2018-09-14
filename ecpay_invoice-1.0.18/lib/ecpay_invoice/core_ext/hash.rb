class Hash
  def stringify_keys
    result = self.class.new
    orig_key_len = keys.length()
    each_key do |key|
      result[key.to_s] = self[key]
    end
    unless result.keys.length() == orig_key_len
        raise "Duplicate key name during convertion, there might be symbol & string key with the same name."
    end
    return result
  end
end

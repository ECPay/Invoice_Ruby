require 'digest'
require 'uri'
require 'cgi'
require 'net/http'
require 'nokogiri'
require 'date'

class APIHelper
    conf = File.join(File.dirname(__FILE__), '..', '..', 'conf', 'invoice_conf.xml')
    @@conf_xml = Nokogiri::XML(File.open(conf))

    def initialize
        active_merc_info = @@conf_xml.xpath('/Conf/MercProfile').text
        @op_mode = @@conf_xml.xpath('/Conf/OperatingMode').text
        @contractor_stat = @@conf_xml.xpath('/Conf/IsProjectContractor').text
        merc_info = @@conf_xml.xpath("/Conf/MerchantInfo/MInfo[@name=\"#{active_merc_info}\"]")
        @ignore_payment = []
        @@conf_xml.xpath('/Conf/IgnorePayment//Method').each {|t| @ignore_payment.push(t.text)}
        if merc_info != []
            @merc_id = merc_info[0].xpath('./MerchantID').text.freeze
            @hkey = merc_info[0].xpath('./HashKey').text.freeze
            @hiv = merc_info[0].xpath('./HashIV').text.freeze

        else
            raise "Specified merchant setting name (#{active_merc_info}) not found."
        end
    end

    def get_mercid()
        return @merc_id
    end

    def get_op_mode()
        return @op_mode
    end

    def get_ignore_pay()
        return @ignore_payment 
    end

    def get_curr_unixtime()
        return Time.now.to_i
    end

    def is_contractor?()
        if @contractor_stat == 'N'
            return false
        elsif @contractor_stat == 'Y'
            return true
        else
            raise "Unknown [IsProjectContractor] configuration."
        end
    end

    def urlencode_dot_net(raw_data, case_tr:'DOWN')
        if raw_data.is_a?(String)
            encoded_data = CGI.escape(raw_data)
            case case_tr
            when 'KEEP'
                # Do nothing
            when 'UP'
                encoded_data.upcase!
            when 'DOWN'
                encoded_data.downcase!
            end
            # Process encoding difference between .NET & CGI
            encoded_data.gsub!('%21', '!')
            encoded_data.gsub!('%2a', '*')
            encoded_data.gsub!('%28', '(')
            encoded_data.gsub!('%29', ')')
            return encoded_data
        else
            raise "Data recieved is not a string."
        end
    end

    def encode_special_param!(params, target_arr)
        if params.is_a?(Hash)
            target_arr.each do |n|
                if params.keys.include?(n)
                    val = self.urlencode_dot_net(params[n])
                    params[n] = val
                end
            end
        end
    end



    def gen_chk_mac_value(params, mode: 1)
        if params.is_a?(Hash)
            # raise exception if param contains CheckMacValue, HashKey, HashIV
            sec = ['CheckMacValue', 'HashKey', 'HashIV']
            sec.each do |pa|
                if params.keys.include?(pa)
                    raise "Parameters shouldn't contain #{pa}"
                end
            end

            raw = params.sort_by{|key,val|key.downcase}.map!{|key,val| "#{key}=#{val}"}.join('&')
            raw = self.urlencode_dot_net(["HashKey=#{@hkey}", raw, "HashIV=#{@hiv}"].join("&"), case_tr: 'DOWN')
            p raw


            case mode
            when 0
            chksum = Digest::MD5.hexdigest(raw)
            when 1
            chksum = Digest::SHA256.hexdigest(raw)
            else
                raise "Unexpected hash mode."
            end
            return chksum.upcase!
        else
            raise "Data recieved is not a Hash."
        end
    end


    def http_request(method:, url:, payload:)

        target_url = URI.parse(url)

        case method
        when 'GET'
          target_url.query = URI.encode_www_form(payload)
          res = Net::HTTP.get_response(target_url)
        when 'POST'
          res = Net::HTTP.post_form(target_url, payload)
        else
          raise ArgumentError, "Only GET & POST method are avaliable."
        end
        return res.body
        # if res == Net::HTTPOK
        #     return res
        # else
        #     raise "#{res.message}, #{res}"
        # end

        # when Net::HTTPClientError, Net::HTTPInternalServerError
        #   raise Net::HTTPError.new(http_response.message, http_response)
        # else
        #   raise Net::HTTPError.new("Unexpected HTTP response.", http_response)
        # end
    end


    def gen_html_post_form(act:, id:, parameters:, input_typ:'hidden', submit: true)
        f = Nokogiri::HTML::Builder.new do |doc|
            doc.form(method: 'post', action: act, id: id) {
                parameters.map{|key,val|
                doc.input(type: input_typ, name: key, id: key, value: val)
                }
                if submit == true
                    doc.script(type: 'text/javascript').text("document.getElementById(\"#{id}\").submit();")
                end
            }
        end
        return f.to_html
    end



end
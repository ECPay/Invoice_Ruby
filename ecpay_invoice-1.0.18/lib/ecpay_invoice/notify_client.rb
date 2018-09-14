require "digest"
require "uri"
require "net/http"
require "net/https"
require "json"
require "date"
require "cgi"
require "ecpay_invoice/helper"
require "ecpay_invoice/verification"
require "ecpay_invoice/error"
require "ecpay_invoice/core_ext/hash"
require "ecpay_invoice/core_ext/string"
# require "../../../gem/lib/ecpay_invoice/helper"
# require "../../../gem/lib/ecpay_invoice/verification"
# require "../../../gem/lib/ecpay_invoice/error"
# require "../../../gem/lib/ecpay_invoice/core_ext/hash"
# require "../../../gem/lib/ecpay_invoice/core_ext/string"

module ECpayInvoice

    class NotifyClientECPay

        def initialize
            @helper = APIHelper.new
        end

        def ecpay_invoice_notify(param)
            notify_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = notify_pos_proc!(params: param, apiname: 'InvoiceNotify')
            return res
        end

        ### Private method definition start ###
        private

            def get_curr_unix_time()
                return Time.now.to_i
            end

            def notify_base_proc!(params:)
                if params.is_a?(Hash)
                    # Transform param key to string
                    params.stringify_keys()

                    params['MerchantID'] = @helper.get_mercid

                else
                    raise ECpayInvalidParam, "Recieved parameter object must be a Hash"
                end
            end

            def notify_pos_proc!(params:, apiname:)
                verify_query_api = ECpayInvoice::NotifyParamVerify.new(apiname)
                verify_query_api.verify_notify_param(params)
                #encode special param
                sp_param = verify_query_api.get_special_encode_param(apiname)
                @helper.encode_special_param!(params, sp_param)

                # Insert chkmacval
                chkmac = @helper.gen_chk_mac_value(params, mode: 0)
                params['CheckMacValue'] = chkmac
                params['NotifyMail'] = CGI::unescape(params['NotifyMail'])
                p params
                # gen post html
                api_url = verify_query_api.get_svc_url(apiname, @helper.get_op_mode)
                #post from server
                resp = @helper.http_request(method: 'POST', url: api_url, payload: params)

                # return  post response
                return resp
            end

        ### Private method definition end ###

    end
end
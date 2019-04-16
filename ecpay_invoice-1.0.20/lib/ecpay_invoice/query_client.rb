require "digest"
require "uri"
require "net/http"
require "net/https"
require "json"
require "date"
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

    class QueryClientECPay

        def initialize
            @helper = APIHelper.new
        end

        def ecpay_query_invoice_issue(param)
            query_base_proc!(params: param)
            unix_time = get_curr_unix_time() + 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = query_pos_proc!(params: param, apiname: 'QueryIssue')
            return res
        end

        def ecpay_query_invoice_allowance(param)
            query_base_proc!(params: param)
            unix_time = get_curr_unix_time() + 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = query_pos_proc!(params: param, apiname: 'QueryAllowance')
            return res
        end

        def ecpay_query_invoice_issue_invalid(param)
            query_base_proc!(params: param)
            unix_time = get_curr_unix_time() + 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = query_pos_proc!(params: param, apiname: 'QueryIssueInvalid')
            return res
        end

        def ecpay_query_invoice_allowance_invalid(param)
            query_base_proc!(params: param)
            unix_time = get_curr_unix_time() + 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = query_pos_proc!(params: param, apiname: 'QueryAllowanceInvalid')
            return res
        end

        def ecpay_query_check_mob_barcode(param)
            query_base_proc!(params: param)
            unix_time = get_curr_unix_time() + 120
            param['TimeStamp'] = unix_time.to_s
            param['BarCode'] = param['BarCode'].to_s.gsub('+', ' ')
            p param['BarCode']
            p param['TimeStamp']
            res = query_pos_proc!(params: param, apiname: 'CheckMobileBarCode')
            return res
        end

        def query_check_love_code(param)
            query_base_proc!(params: param)
            unix_time = get_curr_unix_time() + 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = query_pos_proc!(params: param, apiname: 'CheckLoveCode')
            return res
        end

        ### Private method definition start ###
        private

            def get_curr_unix_time()
                return Time.now.to_i
            end

            def query_base_proc!(params:)
                if params.is_a?(Hash)
                    # Transform param key to string
                    params.stringify_keys()

                    params['MerchantID'] = @helper.get_mercid
                else
                    raise ECpayInvalidParam, "Recieved parameter object must be a Hash"
                end
            end

            def query_pos_proc!(params:, apiname:)
                verify_query_api = ECpayInvoice::QueryParamVerify.new(apiname)
                verify_query_api.verify_query_param(params)
                #encode special param

                # Insert chkmacval
                chkmac = @helper.gen_chk_mac_value(params, mode: 0)
                params['CheckMacValue'] = chkmac
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

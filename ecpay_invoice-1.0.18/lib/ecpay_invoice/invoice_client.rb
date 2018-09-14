require "digest"
require "uri"
require "net/http"
require "net/https"
require "json"
require "cgi"
require "securerandom"
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

	class InvoiceClientECPay
        include ECpayErrorDefinition

        def initialize
            @helper = APIHelper.new
        end

        def ecpay_invoice_issue(param)
            invoice_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
						param['CarruerNum'] = param['CarruerNum'].to_s.gsub('+', ' ')
            p param['TimeStamp']
            res = invoice_pos_proc!(params: param, apiname: 'InvoiceIssue')
            return res
        end

        def ecpay_invoice_delay(param)
            invoice_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
						param['CarruerNum'] = param['CarruerNum'].to_s.gsub('+', ' ')
						param['PayType'] = '2'
						param['PayAct'] = 'ECPAY'
            p param['TimeStamp']
            res = invoice_pos_proc!(params: param, apiname: 'InvoiceDelayIssue')
            return res
        end

        def ecpay_invoice_trigger(param)
            invoice_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
						param['PayType'] = '2'
            p param['TimeStamp']
            res = invoice_pos_proc!(params: param, apiname: 'InvoiceTriggerIssue')
            return res
        end

        def ecpay_invoice_allowance(param)
            invoice_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = invoice_pos_proc!(params: param, apiname: 'InvoiceAllowance')
            return res
        end

        def ecpay_invoice_issue_invalid(param)
            invoice_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = invoice_pos_proc!(params: param, apiname: 'InvoiceIssueInvalid')
            return res
        end

        def ecpay_invoice_allowance_invalid(param)
            invoice_base_proc!(params: param)
            unix_time = get_curr_unix_time() - 120
            param['TimeStamp'] = unix_time.to_s
            p param['TimeStamp']
            res = invoice_pos_proc!(params: param, apiname: 'InvoiceAllowanceInvalid')
            return res
        end

        ### Private method definition start ###
        private

        def get_curr_unix_time()
            return Time.now.to_i
        end

        def invoice_base_proc!(params:)
            if params.is_a?(Hash)
                # Transform param key to string
                params.stringify_keys()

                params['MerchantID'] = @helper.get_mercid

                #gem_uid = SecureRandom::hex
                #p gem_uid.to_s[0, 30]
                #params['RelateNumber'] = gem_uid.to_s[0, 30]

            else
                raise ECpayInvalidParam, "Recieved parameter object must be a Hash"
            end
        end

        def invoice_pos_proc!(params:, apiname:)
            verify_query_api = ECpayInvoice::InvoiceParamVerify.new(apiname)
            if apiname == 'InvoiceIssue'
                exclusive_list = ['InvoiceRemark', 'ItemName', 'ItemRemark', 'ItemWord']
                verify_query_api.verify_inv_issue_param(params)
            elsif apiname == 'InvoiceDelayIssue'
                exclusive_list = ['InvoiceRemark', 'ItemName', 'ItemRemark', 'ItemWord']
                verify_query_api.verify_inv_delay_param(params)
            elsif apiname == 'InvoiceTriggerIssue'
                exclusive_list = []
                verify_query_api.verify_inv_trigger_param(params)
            elsif apiname == 'InvoiceAllowance'
                exclusive_list = ['ItemName', 'ItemWord']
                verify_query_api.verify_inv_allowance_param(params)
            elsif apiname == 'InvoiceIssueInvalid'
                exclusive_list = ['Reason']
                verify_query_api.verify_inv_issue_invalid_param(params)
            elsif apiname == 'InvoiceAllowanceInvalid'
                exclusive_list = ['Reason']
                verify_query_api.verify_inv_allowance_invalid_param(params)
            end

            #encode special param
            sp_param = verify_query_api.get_special_encode_param(apiname)
            @helper.encode_special_param!(params, sp_param)

            exclusive_ele = {}
            for param in exclusive_list
                exclusive_ele[param] = params[param]
                params.delete(param)
            end

            # Insert chkmacval
            chkmac = @helper.gen_chk_mac_value(params, mode: 0)
            params['CheckMacValue'] = chkmac

            for param in exclusive_list
                params[param] = exclusive_ele[param]
            end

            sp_param.each do |key|
                params[key] = CGI::unescape(params[key])
            end

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

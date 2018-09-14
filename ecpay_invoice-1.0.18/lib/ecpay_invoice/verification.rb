
require "ecpay_invoice/error"
# require "../../../gem/lib/ecpay_invoice/error"
require "nokogiri"
require 'date'
module ECpayInvoice
    class InvoiceVerifyBase
        include ECpayErrorDefinition
        @@param_xml = Nokogiri::XML(File.open(File.join(File.dirname(__FILE__), 'ECpayInvoice.xml')))

        def get_svc_url(apiname, mode)
            url = @@param_xml.xpath("/ecpayInvoice/#{apiname}/ServiceAddress/url[@type=\"#{mode}\"]").text
            return url
        end

        def get_special_encode_param(apiname)
            ret = []
            node = @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param[@urlencode=\"1\"]")
            node.each {|elem| ret.push(elem.attributes['name'].value)}
            return ret
        end

        def get_basic_params(apiname)
            basic_param = []
            @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters/param[@require=\"1\"]").each do |elem|
                basic_param.push(elem.attributes['name'].value)
            end
            return basic_param
        end

        def get_cond_param(apiname)
            aio_sw_param = []
            conditional_param = {}
            @@param_xml.xpath("/ecpayInvoice/#{apiname}/Config/switchparam/n").each do |elem|
                aio_sw_param.push(elem.text)
            end
            aio_sw_param.each do |pname|
                opt_param = {}
                node = @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param[@name=\"#{pname}\"]")
                node.xpath('./condparam').each do |elem|
                    opt = elem.attributes['owner'].value
                    params = []
                    elem.xpath('./param[@require="1"]').each do |pa|
                        params.push(pa.attributes['name'].value)
                    end
                    opt_param[opt] = params
                end
                conditional_param[pname] = opt_param
            end
            return conditional_param
        end

        def get_param_type(apiname)
            param_type = {}
            @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param").each do |elem|
                param_type[elem.attributes['name'].value] = elem.attributes['type'].value
            end
            return param_type
        end

        def get_opt_param_pattern(apiname)
            pattern = {}
            node = @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param[@type=\"Opt\"]")
            node.each do |param_elem|
                opt_elems = param_elem.xpath('./option')
                opt = []
                opt_elems.each{|oe|opt.push(oe.text)}
                pattern[param_elem.attributes['name'].value] = opt
            end
            return pattern
        end

        def get_int_param_pattern(apiname)
            pattern = {}
            node = @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param[@type=\"Int\"]")
            node.each do |param_elem|
                mode = param_elem.xpath('./mode').text
                mx = param_elem.xpath('./maximum').text
                mn = param_elem.xpath('./minimal').text
                a = []
                [mode, mx, mn].each{|f|a.push(f)}
                pattern[param_elem.attributes['name'].value] = a
            end
            return pattern
        end

        def get_str_param_pattern(apiname)
            pattern = {}
            node = @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param[@type=\"String\"]")
            node.each do |param_elem|
                p_name = param_elem.attributes['name'].value
                pat_elems = param_elem.xpath('./pattern')
                # if pat_elems.length > 1
                #     raise "Only 1 pattern tag is allowed for each parameter (#{p_name}) "
                # elsif pat_elems.length = 0
                #     raise "No pattern tag found for parameter (#{p_name}) "
                # end
                pat = pat_elems.text
                pattern[p_name] = pat
            end
            return pattern
        end

        def get_depopt_param_pattern(apiname)
            pattern = {}

            node = @@param_xml.xpath("/ecpayInvoice/#{apiname}/Parameters//param[@type=\"DepOpt\"]")
            node.each do |param_elem|
                parent_n_opts = {}
                sub_opts = {}
                p_name = param_elem.attributes['name'].value
                parent_name = param_elem.attributes['main'].value
                param_elem.xpath('./mainoption').each do |elem|
                    k = elem.attributes['name'].value
                    opt = []
                    elem.element_children.each{|c|opt.push(c.text)}
                    sub_opts[k] = opt
                end
                parent_n_opts[parent_name] = sub_opts
                pattern[p_name] = parent_n_opts
            end
            return pattern
        end

        def get_all_pattern(apiname)
            res = {}
            res['Type_idx'] = self.get_param_type(apiname)
            res['Int'] = self.get_int_param_pattern(apiname)
            res['String'] = self.get_str_param_pattern(apiname)
            res['Opt'] = self.get_opt_param_pattern(apiname)
            res['DepOpt'] = self.get_depopt_param_pattern(apiname)
            return res
        end

        def verify_param_by_pattern(params, pattern)
            type_index = pattern['Type_idx']
            params.keys.each do |p_name|
                p_type = type_index[p_name]
                patt_container = pattern[p_type]
                case
                when p_type == 'String'
                    regex_patt = patt_container[p_name]
                    mat = /#{regex_patt}/.match(params[p_name])
                    if mat.nil?
                        raise ECpayInvalidParam, "Wrong format of param #{p_name} or length exceeded."
                    end
                when p_type == 'Opt'
                    aval_opt = patt_container[p_name]
                    mat = aval_opt.include?(params[p_name])
                    if mat == false
                        raise ECpayInvalidParam, "Unexpected option of param #{p_name} (#{params[p_name]}). Avaliable option: (#{aval_opt})."
                    end
                when p_type == 'Int'
                    criteria = patt_container[p_name]
                    mode = criteria[0]
                    max = criteria[1].to_i
                    min = criteria[2].to_i
                    val = params[p_name].to_i
                    case
                    when mode == 'BETWEEN'
                        if val < min or val > max
                            raise ECpayInvalidParam, "Value of #{p_name} should be between #{min} and #{max} ."
                        end
                    when mode == 'GE'
                        if val < min
                            raise ECpayInvalidParam, "Value of #{p_name} should be greater than or equal to #{min}."
                        end
                    when mode == 'LE'
                        if val > max
                            raise ECpayInvalidParam, "Value of #{p_name} should be less than or equal to #{max}."
                        end
                    when mode == 'EXCLUDE'
                        if val >= min and val <= max
                            raise ECpayInvalidParam, "Value of #{p_name} can NOT be between #{min} and #{max} .."
                        end
                    else
                        raise "Unexpected integer verification mode for parameter #{p_name}: #{mode}. "
                    end
                when p_type == 'DepOpt'
                    dep_opt = patt_container[p_name]
                    parent_param = dep_opt.keys()[0]
                    all_dep_opt = dep_opt[parent_param]
                    parent_val = params[parent_param]
                    aval_opt = all_dep_opt[parent_val]
                    if aval_opt.nil? and pattern['Opt'][parent_param].include?(parent_val) == false
                        raise  ECpayInvalidParam, "Cannot find avaliable option of [#{p_name}] by related param [#{parent_param}](Value: #{parent_val})."
                    elsif aval_opt.is_a?(Array)
                        unless aval_opt.include?(params[p_name])
                            raise ECpayInvalidParam, "Unexpected option of param #{p_name} (#{params[p_name]}). Avaliable option: (#{aval_opt})."
                        end
                    end

                else
                    raise "Unexpected type (#{p_type}) for parameter #{p_name}. "

                end
            end
        end
    end

    class InvoiceParamVerify < InvoiceVerifyBase
        include ECpayErrorDefinition
        def initialize(apiname)
            @inv_basic_param = self.get_basic_params(apiname).freeze
            @inv_conditional_param = self.get_cond_param(apiname).freeze
            @all_param_pattern = self.get_all_pattern(apiname).freeze
        end

        def verify_inv_issue_param(params)
            if params.is_a?(Hash)
                #發票所有參數預設要全帶

                if params.has_value?(nil)
                    raise ECpayInvalidParam, %Q{Parameter value cannot be nil}
                end
                #1. 比對欄位是否缺乏
                param_diff = @inv_basic_param - params.keys()
                unless param_diff == []
                    raise ECpayInvalidParam, %Q{Lack required invoice param #{param_diff}}
                end

                #2. 比對特殊欄位值相依需求
                #a [CarruerType]為 1 => CustomerID 不能為空
                if params['CarruerType'].to_s == '1'
                    if params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerID] can not be empty when [CarruerType] is 1."
                    end
                # [CustomerID]不為空 => CarruerType 不能為空
                elsif params['CarruerType'].to_s == ''
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CarruerType] can not be empty when [CustomerID] is not empty."
                    end
                end
                #b 列印註記[Print]為 1 => CustomerName, CustomerAddr
                if params['Print'].to_s == '1'
                    if params['CustomerName'].to_s.empty? or params['CustomerAddr'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerName] and [CustomerAddr] can not be empty when [Print] is 1."
                    end
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Print] can not be '1' when [CustomerID] is not empty."
                    end
                    unless params['CarruerType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Print] can not be '1' when [CarruerType] is not empty."
                    end
                    unless params['CarruerNum'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Print] can not be '1' when [CarruerNum] is not empty."
                    end
                end

                #c CustomerPhone和CustomerEmail至少一個有值
                if  params['CustomerPhone'].to_s.empty? and params['CustomerEmail'].to_s.empty?
                    raise ECpayInvoiceRuleViolate, "[CustomerPhone] and [CustomerEmail] can not both be empty."
                end

                #d [TaxType]為 2 => ClearanceMark = 必須為 1 or 2,ItemTaxType 必須為空
                if params['TaxType'].to_s == '2'
                    if !params['ItemRemark'].to_s.empty?
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount', 'ItemRemark']
                    else
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                    end
                    @vat_params_list = ['ItemCount', 'ItemAmount']
                    unless ['1', '2'].include?(params['ClearanceMark'].to_s)
                        raise ECpayInvoiceRuleViolate, "[ClearanceMark] has to be 1 or 2 when [TaxType] is 2."
                    end
                    unless params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must be empty when [TaxType] is 2."
                    end
                    # 當[TaxType]為2時為零稅率，vat為0時商品單價為免稅，不須再加稅
                    # 若vat為1時商品單價為含稅，須再退稅
                    if params['vat'].to_s == '0'
                        @tax_fee = 1
                    elsif params['vat'].to_s == '1'
                        @tax_fee = 1.05
                    end
                #d.1 [TaxType]為 1 => ItemTaxType, ClearanceMark 必須為空
                elsif params['TaxType'].to_s == '1'
                    if !params['ItemRemark'].to_s.empty?
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount', 'ItemRemark']
                    else
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                    end
                    @vat_params_list = ['ItemCount', 'ItemAmount']
                    unless params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must be empty when [TaxType] is 1."
                    end
                    unless params['ClearanceMark'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ClearanceMark] must be empty when [TaxType] is 1."
                    end
                    # 當[TaxType]為1時為應稅，vat為0時商品單價為免稅，須再加稅
                    # 若vat為1時商品單價為含稅，不須再加稅
                    if params['vat'].to_s == '0'
                        @tax_fee = 1.05
                    elsif params['vat'].to_s == '1'
                        @tax_fee = 1
                    end
                #d.2 [TaxType]為 3 => ItemTaxType, ClearanceMark 必須為空
                elsif params['TaxType'].to_s == '3'
                    if !params['ItemRemark'].to_s.empty?
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount', 'ItemRemark']
                    else
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                    end
                    @vat_params_list = ['ItemCount', 'ItemAmount']
                    unless params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must be empty when [TaxType] is 3."
                    end
                    unless params['ClearanceMark'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ClearanceMark] must be empty when [TaxType] is 3."
                    end
                    # 當[TaxType]為3時為免稅，vat為0時商品單價為免稅，不須再加稅
                    # 若vat為1時商品單價為含稅，須再退稅
                    if params['vat'].to_s == '0'
                        @tax_fee = 1
                    elsif params['vat'].to_s == '1'
                        @tax_fee = 1.05
                    end
                #d.3 [TaxType]為 9 => ItemTaxType 必須為兩項商品（含）以上,且不可為空
                elsif params['TaxType'].to_s == '9'
                    if !params['ItemRemark'].to_s.empty?
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount', 'ItemRemark', 'ItemTaxType']
                    else
                        @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount', 'ItemTaxType']
                    end
                    @vat_params_list = ['ItemCount', 'ItemAmount', 'ItemTaxType']
                    unless params['ItemTaxType'].include?('|')
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must contain at lease one '|'."
                    end
                    if params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] can not be empty when [TaxType] is 9."
                    end
                    # 當[ItmeTaxType]含2選項的話[ClearanceMark]須為1或2
                    if params['ItemTaxType'].include?('2')
                        unless ['1', '2'].include?(params['ClearanceMark'].to_s)
                            raise ECpayInvoiceRuleViolate, "[ClearanceMark] has to be 1 or 2 when [ItemTaxType] has 2."
                        end
                    end
                end

                #e 統一編號[CustomerIdentifier]有值時 => CarruerType != 1, 2 or 3, *Donation = 2, print = 1
                unless params['CustomerIdentifier'].to_s.empty?
                    if ['1', '2', '3'].include?(params['CarruerType'].to_s)
                        raise ECpayInvoiceRuleViolate, "[CarruerType] Cannot be 1, 2 or 3 when [CustomerIdentifier] is given."
                    end
                    unless params['Donation'].to_s == '2' and params['Print'].to_s == '1'
                        raise ECpayInvoiceRuleViolate, "[Print] must be 1 and [Donation] must be 2 when [CustomerIdentifier] is given."
                    end
                end

                # [CarruerType]為'' or 1 時 => CarruerNum = '', [CarruerType]為 2， CarruerNum = 固定長度為 16 且格式為 2 碼大小寫字母加上 14 碼數字。 [CarruerType]為 3 ，帶固定長度為 8 且格式為 1 碼斜線「/」加上由 7 碼數字及大小寫字母組成
                if ['', '1'].include?(params['CarruerType'].to_s)
                    unless params['CarruerNum'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CarruerNum] must be empty when [CarruerType] is empty or 1."
                    end
                elsif params['CarruerType'].to_s == '2'
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerID] must be empty when [CarruerType] is 2."
                    end
                    if /[A-Za-z]{2}[0-9]{14}/.match(params['CarruerNum']).nil?
                        raise ECpayInvoiceRuleViolate, "[CarruerNum] must be 2 alphabets and 14 numbers when [CarruerType] is 2."
                    end
                elsif params['CarruerType'].to_s == '3'
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerID] must be empty when [CarruerType] is 3."
                    end
                    if /^\/[A-Za-z0-9\s+-]{7}$/.match(params['CarruerNum']).nil?
                        raise ECpayInvoiceRuleViolate, "[CarruerNum] must start with '/' followed by 7 alphabet and number characters when [CarruerType] is 3."
                    end
                else
                    raise ECpayInvoiceRuleViolate, "Unexpected value in [CarruerType]."
                end

                # Donation = 1 => LoveCode不能為空, print = 0
                if params['Donation'].to_s == '1'
                    if params['LoveCode'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[LoveCode] cannot be empty when [Donation] is 1."
                    end
                    unless params['Print'].to_s == '0'
                        raise ECpayInvoiceRuleViolate, "[Print] must be 0 when [Donation] is 1."
                    end
                # Donation = 2 => LoveCode不能有值
                elsif params['Donation'].to_s == '2'
                    unless params['LoveCode'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[LoveCode] must be empty when [Donation] is 2."
                    end
                end

                # [vat]為0時 => ItemPrice = 未稅, ItemAmount = (ItemPrice * ItemCount) + (ItemPrice * ItemCount * tax(5%))
                # 未稅加稅單一商品時直接四捨五入帶入ItemAmount，且ItemAmount等於SalesAmount
                # 未稅加稅多樣商品時先算稅金加總帶入ItemAmount，且ItemAmount全部金額加總後帶入SalesAmount後四捨五入
                vat_params = @vat_params_list
                # 商品價錢含有管線 => 認為是多樣商品 *ItemCount ， *ItemPrice ， *ItemAmount 逐一用管線分割，計算數量後與第一個比對
                if params['vat'].to_s == '0'
                    if !params['ItemPrice'].include?('|')
                        unless params['ItemAmount'].to_f == (params['ItemPrice'].to_f * params['ItemCount'].to_i * @tax_fee).round(1)
                            raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{params['ItemPrice'].to_i}) times [ItemCount] (#{params['ItemCount'].to_i}) '*' tax (#{@tax_fee}) subtotal not equal [ItemAmount] (#{params['ItemAmount'].to_i})}
                        end
                        # 驗證單筆商品合計是否等於發票金額
                        unless params['SalesAmount'].to_i == (params['ItemAmount'].to_f).round
                            raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{params['ItemAmount'].to_i}) not equal [SalesAmount] (#{params['SalesAmount'].to_i})}
                        end

                    elsif params['ItemPrice'].include?('|')
                        vat_cnt = params['ItemPrice'].split('|').length
                        vat_params.each do |param_name|
                            # Check if there's empty value.
                            unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                                raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                            end
                            p_cnt = params[param_name].split('|').length
                            unless vat_cnt == p_cnt
                                raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{vat_cnt})}
                            end
                        end
                        vat_amount_arr = params['ItemAmount'].split('|')
                        vat_price_arr = params['ItemPrice'].split('|')
                        vat_count_arr = params['ItemCount'].split('|')
                        (1..vat_cnt).each do |index|
                            if @vat_params_list.length == 3
                                vat_tax_arr = params['ItemTaxType'].split('|')
                                if vat_tax_arr[index - 1].to_s == '1'
                                    @tax_fee = 1.05
                                elsif vat_tax_arr[index - 1].to_s == '2' or vat_tax_arr[index - 1].to_s == '3'
                                    @tax_fee = 1
                                else
                                    raise ECpayInvoiceRuleViolate, "[ItemTaxType] can not be (#{vat_tax_arr[index - 1]}). Avaliable option: (1, 2, 3)."
                                end
                            end
                            unless vat_amount_arr[index - 1].to_f == (vat_price_arr[index - 1].to_f * vat_count_arr[index - 1].to_i * @tax_fee).round(1)
                                raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{vat_price_arr[index - 1].to_f}) times [ItemCount] (#{vat_count_arr[index - 1].to_f}) '*' tax(#{@tax_fee}) not match [ItemAmount] (#{vat_amount_arr[index - 1].to_f})}
                            end
                            #Verify ItemAmount subtotal equal SalesAmount
                            chk_amount_subtotal = 0
                            vat_amount_arr.each do |val|
                                chk_amount_subtotal += val.to_f
                            end
                            unless params['SalesAmount'].to_i == (chk_amount_subtotal.to_f).round
                                raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{vat_amount_arr}) subtotal not equal [SalesAmount] (#{params['SalesAmount'].to_i})}
                            end
                        end
                    end
                end

                # [vat]為1時 => ItemPrice = 含稅, ItemAmount = ItemPrice * ItemCount
                # 商品價錢含有管線 => 認為是多樣商品 *ItemCount ， *ItemPrice ， *ItemAmount 逐一用管線分割，計算數量後與第一個比對
                # 含稅扣稅單一商品時直接四捨五入帶入ItemAmount，且ItemAmount等於SalesAmount
                # 含稅扣稅多樣商品時先算稅金加總四捨五入後帶入ItemAmount，且ItemAmount全部金額加總後等於SalesAmount
                if params['vat'].to_s == '1'
                    if !params['ItemPrice'].include?('|')

                        unless params['ItemAmount'].to_f == (params['ItemPrice'].to_f * params['ItemCount'].to_i / @tax_fee).round(1)

                            raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{params['ItemPrice'].to_f}) times [ItemCount] (#{params['ItemCount'].to_f}) '/' tax (#{@tax_fee}) subtotal not equal [ItemAmount] (#{params['ItemAmount'].to_f})}
                        end
                        # 驗證單筆商品合計是否等於發票金額
                        unless params['SalesAmount'].to_i == (params['ItemAmount'].to_f).round
                            raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{params['ItemAmount'].to_i}) not equal [SalesAmount] (#{params['SalesAmount'].to_i})}
                        end
                    elsif params['ItemPrice'].include?('|')
                        vat_cnt = params['ItemPrice'].split('|').length
                        vat_params.each do |param_name|
                            # Check if there's empty value.
                            unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                                raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                            end
                            p_cnt = params[param_name].split('|').length
                            unless vat_cnt == p_cnt
                                raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{vat_cnt})}
                            end
                        end
                        vat_amount_arr = params['ItemAmount'].split('|')
                        vat_price_arr = params['ItemPrice'].split('|')
                        vat_count_arr = params['ItemCount'].split('|')
                        (1..vat_cnt).each do |index|
                            if @vat_params_list.length == 3
                                vat_tax_arr = params['ItemTaxType'].split('|')
                                if vat_tax_arr[index - 1].to_s == '1'
                                    @tax_fee = 1
                                elsif vat_tax_arr[index - 1].to_s == '2' or vat_tax_arr[index - 1].to_s == '3'
                                    @tax_fee = 1.05
                                else
                                    raise ECpayInvoiceRuleViolate, "[ItemTaxType] can not be (#{vat_tax_arr[index - 1]}). Avaliable option: (1, 2, 3)."
                                end
                            end
                            unless vat_amount_arr[index - 1].to_f == (vat_price_arr[index - 1].to_f * vat_count_arr[index - 1].to_i / @tax_fee).round(1)
                                raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{vat_price_arr[index - 1]}) times [ItemCount] (#{vat_count_arr[index - 1]}) '/' tax(#{@tax_fee}) not match [ItemAmount] (#{vat_amount_arr[index - 1].to_i})}
                            end
                            #Verify ItemAmount subtotal equal SalesAmount
                            chk_amount_subtotal = 0
                            vat_amount_arr.each do |val|
                                chk_amount_subtotal += val.to_f
                            end
                            unless params['SalesAmount'].to_i == (chk_amount_subtotal.to_f).round
                                raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{vat_amount_arr}) subtotal not equal [SalesAmount] (#{params['SalesAmount'].to_i})}
                            end
                        end
                    end
                end

                #3. 比對商品名稱，數量，單位，價格，tax，合計，備註項目數量是否一致，欄位是否為空
                if params['ItemName'].to_s.empty? or params['ItemWord'].to_s.empty?
                    raise ECpayInvoiceRuleViolate, "[ItemName] or [ItemWord] cannot be empty"
                end

                # ItemTaxType and ItemRemark會因為TaxType and ItemRemark is not empty 新增至@item_params_list
                item_params = @item_params_list
                #商品名稱含有管線 => 認為是多樣商品 *ItemName， *ItemCount ，*ItemWord， *ItemPrice， *ItemAmount， *ItemTaxType， *ItemRemark逐一用管線分割，計算數量後與第一個比對
                if params['ItemName'].include?('|')
                    item_cnt = params['ItemName'].split('|').length
                    item_params.each do |param_name|
                        # Check if there's empty value.
                        unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                            raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                        end
                        p_cnt = params[param_name].split('|').length
                        unless item_cnt == p_cnt
                            raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{item_cnt})}
                        end
                    end
                    # 課稅類別[TaxType] = 9 時 => ItemTaxType 能含有1,2 3(and at least contains one 1 and other)
                    if params['TaxType'].to_s == '9'
                        item_tax = params['ItemTaxType'].split('|')
                        p item_tax
                        aval_tax_type = ['1', '2', '3']
                        vio_tax_t = (item_tax - aval_tax_type)
                        unless vio_tax_t == []
                            raise ECpayInvoiceRuleViolate, "Ilegal [ItemTaxType]: #{vio_tax_t}"
                        end
                        unless item_tax.include?('1')
                            raise ECpayInvoiceRuleViolate, "[ItemTaxType] must contain at lease one '1'."
                        end
                        if item_cnt >= 2
                            if !item_tax.include?('2') and !item_tax.include?('3')
                                raise ECpayInvoiceRuleViolate, "[ItemTaxType] cannot be all 1 when [TaxType] is 9."
                            end
                        end
                        if item_tax.include?('2') and item_tax.include?('3')
                            raise ECpayInvoiceRuleViolate, "[ItemTaxType] cannot contain 2 and 3 at the same time."
                        end
                    end
                else
                    #沒有管線 => 逐一檢查@item_params_list的欄位有無管線
                    item_params.each do |param_name|
                        if params[param_name].include?('|')
                            raise "Item info [#{param_name}] contains pipeline delimiter but there's only one item in param [ItemName]"
                        end
                    end
                end

                #4 比對所有欄位Pattern
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end
        end

        def verify_inv_delay_param(params)
            if params.is_a?(Hash)
                #發票所有參數預設要全帶

                if params.has_value?(nil)
                    raise ECpayInvalidParam, %Q{Parameter value cannot be nil}
                end
                #1. 比對欄位是否缺乏
                param_diff = @inv_basic_param - params.keys()
                unless param_diff == []
                    raise ECpayInvalidParam, %Q{Lack required invoice param #{param_diff}}
                end

                #2. 比對特殊欄位值相依需求
                #a [CarruerType]為 1 => CustomerID 不能為空
                if params['CarruerType'].to_s == '1'
                    if params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerID] can not be empty when [CarruerType] is 1."
                    end
                    # [CustomerID]不為空 => CarruerType 不能為空
                elsif params['CarruerType'].to_s == ''
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CarruerType] can not be empty when [CustomerID] is not empty."
                    end
                end
                #b 列印註記[Print]為 1 => CustomerName, CustomerAddr
                if params['Print'].to_s == '1'
                    if params['CustomerName'].to_s.empty? or params['CustomerAddr'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerName] and [CustomerAddr] can not be empty when [Print] is 1."
                    end
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Print] can not be '1' when [CustomerID] is not empty."
                    end
                    unless params['CarruerType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Print] can not be '1' when [CarruerType] is not empty."
                    end
                    unless params['CarruerNum'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Print] can not be '1' when [CarruerNum] is not empty."
                    end
                end

                #c CustomerPhone和CustomerEmail至少一個有值
                if  params['CustomerPhone'].to_s.empty? and params['CustomerEmail'].to_s.empty?
                    raise ECpayInvoiceRuleViolate, "[CustomerPhone] and [CustomerEmail] can not both be empty."
                end

                #d [TaxType]為 2 => ClearanceMark = 必須為 1 or 2,ItemTaxType 必須為空
                if params['TaxType'].to_s == '2'
                    @tax_fee = 1.05
                    @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                    @vat_params_list = ['ItemCount', 'ItemAmount']
                    unless ['1', '2'].include?(params['ClearanceMark'].to_s)
                        raise ECpayInvoiceRuleViolate, "[ClearanceMark] has to be 1 or 2 when [TaxType] is 2."
                    end
                    unless params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must be empty when [TaxType] is 2."
                    end
                    #d.1 [TaxType]為 1 => ItemTaxType, ClearanceMark 必須為空
                elsif params['TaxType'].to_s == '1'
                    @tax_fee = 1
                    @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                    @vat_params_list = ['ItemCount', 'ItemAmount']
                    unless params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must be empty when [TaxType] is 1."
                    end
                    unless params['ClearanceMark'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ClearanceMark] must be empty when [TaxType] is 1."
                    end
                    #d.2 [TaxType]為 3 => ItemTaxType, ClearanceMark 必須為空
                elsif params['TaxType'].to_s == '3'
                    @tax_fee = 1.05
                    @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                    @vat_params_list = ['ItemCount', 'ItemAmount']
                    unless params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must be empty when [TaxType] is 3."
                    end
                    unless params['ClearanceMark'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ClearanceMark] must be empty when [TaxType] is 3."
                    end
                    #d.3 [TaxType]為 9 => ItemTaxType 必須為兩項商品（含）以上,且不可為空
                elsif params['TaxType'].to_s == '9'
                    @item_params_list = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount', 'ItemTaxType']
                    @vat_params_list = ['ItemCount', 'ItemAmount', 'ItemTaxType']
                    unless params['ItemTaxType'].include?('|')
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] must contain at lease one '|'."
                    end
                    if params['ItemTaxType'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[ItemTaxType] can not be empty when [TaxType] is 9."
                    end
                end

                #e 統一編號[CustomerIdentifier]有值時 => CarruerType != 1, 2 or 3, *Donation = 2, print = 1
                unless params['CustomerIdentifier'].to_s.empty?
                    if ['1', '2', '3'].include?(params['CarruerType'].to_s)
                        raise ECpayInvoiceRuleViolate, "[CarruerType] Cannot be 1, 2 or 3 when [CustomerIdentifier] is given."
                    end
                    unless params['Donation'].to_s == '2' and params['Print'].to_s == '1'
                        raise ECpayInvoiceRuleViolate, "[Print] must be 1 and [Donation] must be 2 when [CustomerIdentifier] is given."
                    end
                end

                # DelayFlag Rules When [DelayFlag] is '1' the [DelayDay] range be between 1 and 15
                # When [DelayFlag] is '2' the [DelayDay] range be between 0 and 15
                if params['DelayFlag'].to_s == '1'
                    if params['DelayDay'].to_i > 15 or params['DelayDay'].to_i < 1
                        raise ECpayInvoiceRuleViolate, "[DelayDay] must be between 1 and 15  when [DelayFlag] is '1'."
                    end
                elsif params['DelayFlag'].to_s == '2'
                    if params['DelayDay'].to_i > 15 or params['DelayDay'].to_i < 0
                        raise ECpayInvoiceRuleViolate, "[DelayDay] must be between 0 and 15  when [DelayFlag] is '2'."
                    end
                end

                # [CarruerType]為'' or 1 時 => CarruerNum = '', [CarruerType]為 2， CarruerNum = 固定長度為 16 且格式為 2 碼大小寫字母加上 14 碼數字。 [CarruerType]為 3 ，帶固定長度為 8 且格式為 1 碼斜線「/」加上由 7 碼數字及大小寫字母組成
                if ['', '1'].include?(params['CarruerType'].to_s)
                    unless params['CarruerNum'].to_s == ''
                        raise ECpayInvoiceRuleViolate, "[CarruerNum] must be empty when [CarruerType] is empty or 1."
                    end
                elsif params['CarruerType'].to_s == '2'
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerID] must be empty when [CarruerType] is 3."
                    end
                    if /[A-Za-z]{2}[0-9]{14}/.match(params['CarruerNum']).nil?
                        raise ECpayInvoiceRuleViolate, "[CarruerNum] must be 2 alphabets and 14 numbers when [CarruerType] is 2."
                    end
                elsif params['CarruerType'].to_s == '3'
                    unless params['CustomerID'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[CustomerID] must be empty when [CarruerType] is 3."
                    end
                    if /^\/[A-Za-z0-9\s+-]{7}$/.match(params['CarruerNum']).nil?
                        raise ECpayInvoiceRuleViolate, "[CarruerNum] must start with '/' followed by 7 alphabet and number characters when [CarruerType] is 3."
                    end
                else
                    raise ECpayInvoiceRuleViolate, "Unexpected value in [CarruerType]."
                end

                # Donation = 1 => LoveCode不能為空, print = 0
                if params['Donation'].to_s == '1'
                    if params['LoveCode'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[LoveCode] cannot be empty when [Donation] is 1."
                    end
                    unless params['Print'].to_s == '0'
                        raise ECpayInvoiceRuleViolate, "[Print] must be 0 when [Donation] is 1."
                    end
                # Donation = 2 => LoveCode不能有值
                elsif params['Donation'].to_s == '2'
                    unless params['LoveCode'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[LoveCode] must be empty when [Donation] is 2."
                    end
                end

                vat_params = @vat_params_list
                # 商品價錢含有管線 => 認為是多樣商品 *ItemCount ， *ItemPrice ， *ItemAmount 逐一用管線分割，計算數量後與第一個比對
                if !params['ItemPrice'].include?('|')
                    unless params['ItemAmount'].to_f == (params['ItemPrice'].to_f * params['ItemCount'].to_i / @tax_fee).round(1)
                        raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{params['ItemPrice'].to_i}) times [ItemCount] (#{params['ItemCount'].to_i}) '/' tax (#{@tax_fee}) subtotal not equal [ItemAmount] (#{params['ItemAmount'].to_i})}
                    end
                    # 驗證單筆商品合計是否等於發票金額
                    unless params['SalesAmount'].to_i == (params['ItemAmount'].to_f).round
                        raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{params['ItemAmount'].to_i}) not equal [SalesAmount] (#{params['SalesAmount'].to_i})}
                    end
                elsif params['ItemPrice'].include?('|')
                    vat_cnt = params['ItemPrice'].split('|').length
                    vat_params.each do |param_name|
                        # Check if there's empty value.
                        unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                            raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                        end
                        p_cnt = params[param_name].split('|').length
                        unless vat_cnt == p_cnt
                            raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{vat_cnt})}
                        end
                    end
                    vat_amount_arr = params['ItemAmount'].split('|')
                    vat_price_arr = params['ItemPrice'].split('|')
                    vat_count_arr = params['ItemCount'].split('|')
                    (1..vat_cnt).each do |index|
                        if @vat_params_list.length == 3
                            vat_tax_arr = params['ItemTaxType'].split('|')
                            if vat_tax_arr[index - 1].to_s == '1'
                                @tax_fee = 1
                            elsif vat_tax_arr[index - 1].to_s == '2' or vat_tax_arr[index - 1].to_s == '3'
                                @tax_fee = 1.05
                            else
                                raise ECpayInvoiceRuleViolate, "[ItemTaxType] can not be (#{vat_tax_arr[index - 1]}). Avaliable option: (1, 2, 3)."
                            end
                        end
                        unless vat_amount_arr[index - 1].to_f == (vat_price_arr[index - 1].to_f * vat_count_arr[index - 1].to_f / @tax_fee).round(1)
                            raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{vat_price_arr[index - 1]}) times [ItemCount] (#{vat_count_arr[index - 1]}) '/' tax(#{@tax_fee}) not match [ItemAmount] (#{vat_amount_arr[index - 1].to_i})}
                        end
                        #Verify ItemAmount subtotal equal SalesAmount
                        chk_amount_subtotal = 0
                        vat_amount_arr.each do |val|
                            chk_amount_subtotal += val.to_f
                        end
                        unless params['SalesAmount'].to_i == chk_amount_subtotal.round
                            raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{vat_amount_arr}) subtotal not equal [SalesAmount] (#{params['SalesAmount'].to_i})}
                        end
                    end
                end

                #3. 比對商品名稱，數量，單位，價格，tax，合計，備註項目數量是否一致，欄位是否為空
                if params['ItemName'].to_s.empty? or params['ItemWord'].to_s.empty?
                    raise ECpayInvoiceRuleViolate, "[ItemName] or [ItemWord] cannot be empty"
                end
                item_params = @item_params_list
                #商品名稱含有管線 => 認為是多樣商品 *ItemName， *ItemCount ，*ItemWord， *ItemPrice， *ItemAmount逐一用管線分割，計算數量後與第一個比對
                if params['ItemName'].include?('|')
                    item_cnt = params['ItemName'].split('|').length
                    item_params.each do |param_name|
                        # Check if there's empty value.
                        unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                            raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                        end
                        p_cnt = params[param_name].split('|').length
                        unless item_cnt == p_cnt
                            raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{item_cnt})}
                        end
                    end
                    # 課稅類別[TaxType] = 9 時 => ItemTaxType 能含有1,2 3(and at least contains one 1 and other)
                    if params['TaxType'].to_s == '9'
                        item_tax = params['ItemTaxType'].split('|')
                        p item_tax
                        aval_tax_type = ['1', '2', '3']
                        vio_tax_t = (item_tax - aval_tax_type)
                        unless vio_tax_t == []
                            raise ECpayInvoiceRuleViolate, "Ilegal [ItemTaxType]: #{vio_tax_t}"
                        end
                        unless item_tax.include?('1')
                            raise ECpayInvoiceRuleViolate, "[ItemTaxType] must contain at lease one '1'."
                        end
                        if !item_tax.include?('2') and !item_tax.include?('3')
                            raise ECpayInvoiceRuleViolate, "[ItemTaxType] cannot be all 1 when [TaxType] is 9."
                        end
                    end
                else
                    #沒有管線 => 逐一檢查後6項有無管線
                    item_params.each do |param_name|
                        if params[param_name].include?('|')
                            raise "Item info [#{param_name}] contains pipeline delimiter but there's only one item in param [ItemName]"
                        end
                    end
                end

                #4 比對所有欄位Pattern
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end
        end

        def verify_inv_trigger_param(params)
            if params.is_a?(Hash)
                param_diff = @inv_basic_param - params.keys
                unless param_diff == []
                    raise ECpayInvalidParam, "Lack required param #{param_diff}"
                end

                #Verify Value pattern of each param
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end

        end

        def verify_inv_allowance_param(params)
            if params.is_a?(Hash)
                #發票所有參數預設要全帶

                if params.has_value?(nil)
                    raise ECpayInvalidParam, %Q{Parameter value cannot be nil}
                end
                #1. 比對欄位是否缺乏
                param_diff = @inv_basic_param - params.keys()
                unless param_diff == []
                    raise ECpayInvalidParam, %Q{Lack required invoice param #{param_diff}}
                end

                #2. 比對特殊欄位值相依需求
                #NotifyPhone和NotifyMail至少一個有值
                if params['AllowanceNotify'].to_s == 'S'
                    if params['NotifyPhone'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[NotifyPhone] cannot be empty."
                    end
                elsif params['AllowanceNotify'].to_s == 'E'
                    if params['NotifyMail'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[NotifyMail] cannot be empty."
                    end
                elsif params['AllowanceNotify'].to_s == 'A'
                    if params['NotifyPhone'].to_s.empty? or params['NotifyMail'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[NotifyPhone] and [NotifyMail] can not be empty."
                    end
                end

                vat_params = ['ItemCount', 'ItemAmount']
                # 商品價錢含有管線 => 認為是多樣商品 *ItemCount ， *ItemPrice ， *ItemAmount 逐一用管線分割，計算數量後與第一個比對
                # 驗證單筆ItemAmount = (ItemPrice * ItemCount)
                if !params['ItemPrice'].include?('|')
                    unless params['ItemAmount'].to_f == (params['ItemPrice'].to_f * params['ItemCount'].to_i).round(1)
                        raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{params['ItemPrice'].to_i}) times [ItemCount] (#{params['ItemCount'].to_i}) subtotal not equal [ItemAmount] (#{params['ItemAmount'].to_i})}
                    end
                    # 驗證單筆商品合計是否等於發票金額
                    unless params['AllowanceAmount'].to_i == (params['ItemAmount'].to_f).round
                        raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{params['ItemAmount'].to_i}) not equal [AllowanceAmount] (#{params['AllowanceAmount'].to_i})}
                    end
                elsif params['ItemPrice'].include?('|')
                    vat_cnt = params['ItemPrice'].split('|').length
                    vat_params.each do |param_name|
                        # Check if there's empty value.
                        unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                            raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                        end
                        p_cnt = params[param_name].split('|').length
                        unless vat_cnt == p_cnt
                            raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{vat_cnt})}
                        end
                    end
                    vat_amount_arr = params['ItemAmount'].split('|')
                    vat_price_arr = params['ItemPrice'].split('|')
                    vat_count_arr = params['ItemCount'].split('|')
                    (1..vat_cnt).each do |index|
                        unless vat_amount_arr[index - 1].to_f == (vat_price_arr[index - 1].to_f * vat_count_arr[index - 1].to_f).round(1)
                            raise ECpayInvoiceRuleViolate, %Q{[ItemPrice] (#{vat_price_arr[index - 1]}) times [ItemCount] (#{vat_count_arr[index - 1]}) not match [ItemAmount] (#{vat_amount_arr[index - 1].to_i})}
                        end
                        #Verify ItemAmount subtotal equal SalesAmount
                        chk_amount_subtotal = 0
                        vat_amount_arr.each do |val|
                            chk_amount_subtotal += val.to_f
                        end
                        unless params['AllowanceAmount'].to_i == (chk_amount_subtotal.to_f).round(0)
                            raise ECpayInvoiceRuleViolate, %Q{[ItemAmount] (#{vat_amount_arr}) subtotal not equal [AllowanceAmount] (#{params['AllowanceAmount'].to_i})}
                        end
                    end
                end

                #3. 比對商品名稱，數量，單位，價格，tax，合計，備註項目數量是否一致，欄位是否為空
                if params['ItemName'].to_s.empty? or params['ItemWord'].to_s.empty?
                    raise ECpayInvoiceRuleViolate, "[ItemName] or [ItemWord] cannot be empty"
                end
                item_params = ['ItemCount', 'ItemWord', 'ItemPrice', 'ItemAmount']
                #商品名稱含有管線 => 認為是多樣商品 *ItemName， *ItemCount ，*ItemWord， *ItemPrice， *ItemAmount逐一用管線分割，計算數量後與第一個比對
                if params['ItemName'].include?('|')
                    item_cnt = params['ItemName'].split('|').length
                    item_params.each do |param_name|
                        # Check if there's empty value.
                        unless /(\|\||^\||\|$)/.match(params[param_name]).nil?
                            raise ECpayInvoiceRuleViolate, "[#{param_name}] contains empty value."
                        end
                        p_cnt = params[param_name].split('|').length
                        unless item_cnt == p_cnt
                            raise ECpayInvoiceRuleViolate, %Q{Count of item info [#{param_name}] (#{p_cnt}) not match item count from [ItemCount] (#{item_cnt})}
                        end
                    end
                    # ItemTaxType 能含有1,2 3(and at least contains one 1 and other)
                    if params['ItemTaxType'].include?('|')
                        item_tax = params['ItemTaxType'].split('|')
                        aval_tax_type = ['1', '3']
                        vio_tax_t = (item_tax - aval_tax_type)
                        unless vio_tax_t == []
                            raise ECpayInvoiceRuleViolate, "Ilegal [ItemTaxType]: #{vio_tax_t}"
                        end
                    end
                else
                    #沒有管線 => 逐一檢查後6項有無管線
                    item_params.each do |param_name|
                        if params[param_name].include?('|')
                            raise "Item info [#{param_name}] contains pipeline delimiter but there's only one item in param [ItemName]"
                        end
                    end
                end

                #4 比對所有欄位Pattern
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end
        end

        def verify_inv_issue_invalid_param(params)
            if params.is_a?(Hash)
                param_diff = @inv_basic_param - params.keys
                unless param_diff == []
                    raise ECpayInvalidParam, "Lack required param #{param_diff}"
                end

                #Verify Value pattern of each param
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end

        end

        def verify_inv_allowance_invalid_param(params)
            if params.is_a?(Hash)
                param_diff = @inv_basic_param - params.keys
                unless param_diff == []
                    raise ECpayInvalidParam, "Lack required param #{param_diff}"
                end

                #Verify Value pattern of each param
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end

        end
    end

    class QueryParamVerify < InvoiceVerifyBase
        include ECpayErrorDefinition
        def initialize(apiname)
            @inv_basic_param = self.get_basic_params(apiname).freeze
            @inv_conditional_param = self.get_cond_param(apiname).freeze
            @all_param_pattern = self.get_all_pattern(apiname).freeze
        end

        def verify_query_param(params)
            if params.is_a?(Hash)
                param_diff = @inv_basic_param - params.keys
                unless param_diff == []
                    raise ECpayInvalidParam, "Lack required param #{param_diff}"
                end

                #Verify Value pattern of each param
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end

        end
    end

    class NotifyParamVerify < InvoiceVerifyBase
        include ECpayErrorDefinition
        def initialize(apiname)
            @inv_basic_param = self.get_basic_params(apiname).freeze
            @inv_conditional_param = self.get_cond_param(apiname).freeze
            @all_param_pattern = self.get_all_pattern(apiname).freeze
        end

        def verify_notify_param(params)
            if params.is_a?(Hash)
                #發送發票通知預設參數要全帶

                if params.has_value?(nil)
                    raise ECpayInvalidParam, %Q{Parameter value cannot be nil}
                end
                #1. 比對欄位是否缺乏
                param_diff = @inv_basic_param - params.keys()
                unless param_diff == []
                    raise ECpayInvalidParam, %Q{Lack required invoice param #{param_diff}}
                end

                #2. 比對特殊欄位值相依需求
                #a Phone和NotifyMail至少一個有值
                if  params['Phone'].to_s.empty? and params['NotifyMail'].to_s.empty?
                    raise ECpayInvoiceRuleViolate, "[Phone] and [NotifyMail] can not both be empty."
                end

                #b [Notify] is S [Phone] can not be empty or [Notify] is E [NotifyMail] can not be empty
                # If [Notify] is A [Phone] and [NotifyMail] can not both be empty
                if params['Notify'].to_s == 'S'
                    if params['Phone'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Phone] can not be empty when [Notify] is 'S'."
                    end
                elsif params['Notify'].to_s == 'E'
                    if params['NotifyMail'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[NotifyMail] can not be empty when [Notify] is 'E'."
                    end
                elsif params['Notify'].to_s == 'A'
                    if params['Phone'].to_s.empty? or params['NotifyMail'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[Phone] and [NotifyMail] can not be empty when [Notify] is 'A'."
                    end
                else
                    raise ECpayInvoiceRuleViolate, "Unexpected value in [Notify]."
                end

                #c [InvoiceTag] is I,II,A,AI,AW [InvoiceNo] can not be empty or [InvoiceTag] is A,AI [AllowanceNo] can not be empty
                if params['InvoiceTag'].to_s == 'I' or params['InvoiceTag'].to_s == 'II' or params['InvoiceTag'].to_s == 'AW'
                    if params['InvoiceNo'].to_s.empty?
                        raise ECpayInvoiceRuleViolate, "[InvoiceNo] can not be empty."
                    end
                elsif params['InvoiceTag'].to_s == 'A' or params['InvoiceTag'].to_s == 'AI'
                    if /^\d{16}$/.match(params['AllowanceNo']).nil?
                        raise ECpayInvoiceRuleViolate, "[AllowanceNo] must followed by 16 number characters when [InvoiceTag] is 'A' or 'AI'."
                    end
                    if params['InvoiceNo'].to_s.empty?
                        if params['AllowanceNo'].to_s.empty?
                            raise ECpayInvoiceRuleViolate, "[InvoiceNo] and [AllowanceNo] can not be empty when [Notify] is 'A' or 'AI'."
                        end
                        raise ECpayInvoiceRuleViolate, "[InvoiceNo] can not be empty."
                    end
                    unless params['InvoiceNo'].to_s.empty?
                        if params['AllowanceNo'].to_s.empty?
                            raise ECpayInvoiceRuleViolate, "[AllowanceNo] can not be empty."
                        end
                    end
                else
                    raise ECpayInvoiceRuleViolate, "Unexpected value in [InvoiceTag]."
                end

                #Verify Value pattern of each param
                self.verify_param_by_pattern(params, @all_param_pattern)

            else
                raise TypeError, "Recieved argument is not a hash"
            end

        end
    end
end

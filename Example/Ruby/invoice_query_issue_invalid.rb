require 'ecpay_invoice'

class YOURCONTROLLER < ApplicationController
	# 查詢作廢發票明細
	def InvQueryIssueInvalid
		## 參數值為[PLEASE MODIFY]者，請每次測試時給予獨特值
		query_issue_invalid_dict = {
			"RelateNumber"=>"23u4923hvn9sa9rh23894fj2983489" # 輸入合作特店自訂的編號，長度為30字元
		}
		
		query_issue_invalid = ECpayInvoice::QueryClientECPay.new # 將模組中的class實例化
		res = query_issue_invalid.ecpay_query_invoice_issue_invalid(query_issue_invalid_dict) # 對class中的對應的method傳入位置參數
		
		render :text => res # 將回傳結果列印出來
	end
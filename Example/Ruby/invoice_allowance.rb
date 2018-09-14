require 'ecpay_invoice'

		## 參數值為[PLEASE MODIFY]者，請每次測試時給予獨特值
		inv_allowance_dict = {
			"InvoiceNo"=>"FX60011814", # 發票號碼，長度為10字元
			"AllowanceNotify"=>"E", # 通知類別
			"CustomerName"=>"", # 客戶名稱
			"NotifyPhone"=>"0922652130", # 通知手機號碼
			"NotifyMail"=>"ying.wu@ecpay.com.tw", # 通知電子信箱
			"AllowanceAmount"=>"401", # 折讓單總金額
			"ItemName"=>"洗衣精1|洗衣精2|洗衣精3", # 商品名稱，如果超過一樣商品時請以｜分隔
			"ItemCount"=>"2|1|1", # 商品數量，如果超過一樣商品時請以｜分隔
			"ItemWord"=>"瓶|瓶|瓶", # 商品單位，如果超過一樣商品時請以｜分隔
			"ItemPrice"=>"100.3|100.3|100.3", # 商品價格，如果超過一樣商品時請以｜分隔
			"ItemTaxType"=>"1|1|1", # 商品課稅.3別，如果超過一樣商品時請以｜分隔
			"ItemAmount"=>"200.6|100.3|100.3" # 商品合計，如果超過一樣商品時請以｜分隔
		} 
		
		inv_allowance = ECpayInvoice::InvoiceClientECPay.new # 將模組中的class實例化
		res = inv_allowance.ecpay_invoice_allowance(inv_allowance_dict) # 對class中的對應的method傳入位置參數
		
		puts res # 將回傳結果列印出來
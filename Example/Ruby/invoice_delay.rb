require 'ecpay_invoice'

		## 參數值為[PLEASE MODIFY]者，請每次測試時給予獨特值
		inv_delay_dict = {
			"RelateNumber"=>"PLEASEdsadsadsaMODIFY", # 請帶30碼uid, ex: werntfg9os48trhw34etrwerh8ew2r
			"CustomerID"=>"123",
			"CustomerIdentifier"=>"",
			"CustomerName"=>"綠先生",
			"CustomerAddr"=>"台北市南港區三重路19-2號6-2樓",
			"CustomerPhone"=>"0912345678",
			"CustomerEmail"=>"ying.wu@ecpay.com.tw",
			"ClearanceMark"=>"",
			"Print"=>"1",
			"Donation"=>"0",
			"LoveCode"=>"",
			"CarruerType"=>"",
			"CarruerNum"=>"",
			"TaxType"=>"1",
			"SalesAmount"=>"600",
			"InvoiceRemark"=>"",
			"ItemName"=>"洗衣精|洗髮乳",
			"ItemCount"=>"3|3",
			"ItemWord"=>"瓶|罐",
			"ItemPrice"=>"100|100",
			"ItemTaxType"=>"",
			"ItemAmount"=>"300|300",
			"InvType"=>"07",
			"DelayFlag"=>"2", # 延遲註記，僅可帶入'1'延遲開立、'2'觸發開立，當為'2'時須透過invoice_trigger進行觸發
			"DelayDay"=>"15", # 延遲開立，當為延遲註記為'1'，延遲天數範圍為1至15天，當為延遲註記為'2'，延遲天數範圍為0至15天
			"Tsr"=>"PLEASEdsadsadsaMODIFY", # 交易單號，不可重複，請帶30碼uid, ex: nws349sher9toreterstuferyo345g，為invoice_trigger的觸發依據
			"PayType"=>"2", # 交易類別，請固定帶'2'
			"PayAct"=>"ECPAY", # 交易類別名稱，請固定帶'ECPAY'
			"NotifyURL"=>"" # 開立完成時通知會員系統的網址
		}
		
		inv_delay = ECpayInvoice::InvoiceClientECPay.new # 將模組中的class實例化
		res = inv_delay.ecpay_invoice_delay(inv_delay_dict) # 對class中的對應的method傳入位置參數
		
		puts res # 將回傳結果列印出來

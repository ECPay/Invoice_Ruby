require 'ecpay_invoice'


		## 參數值為[PLEASE MODIFY]者，請每次測試時給予獨特值
		inv_issue_dict = {
			"RelateNumber"=>"54645134141s4dasd", # 請帶30碼uid, ex: werntfg9os48trhw34etrwerh8ew2r
			"CustomerID"=>"4141", # 客戶代號，長度為20字元
			"CustomerIdentifier"=>"", # 統一編號，長度為8字元
			"CustomerName"=>"綠先生", # 客戶名稱，長度為20字元
			"CustomerAddr"=>"台北市南港區三重路19-2號6-2樓", # 客戶地址，長度為100字元
			"CustomerPhone"=>"0912345678", # 客戶電話，長度為20字元
			"CustomerEmail"=>"ying.wu@ecpay.com.tw", # 客戶信箱，長度為80字元
			"ClearanceMark"=>"", # 通關方式，僅可帶入'1'、'2'、''
			"Print"=>"1", # 列印註記，僅可帶入'0'、'1'
			"Donation"=>"0", # 捐贈註記，僅可帶入'1'、'0'
			"LoveCode"=>"", # 愛心碼，長度為7字元
			"CarruerType"=>"", # 載具類別，僅可帶入'1'、'2'、'3'、''
			"CarruerNum"=>"", # 載具編號，當載具類別為'2'時，長度為16字元，當載具類別為'3'時，長度為7字元
			"TaxType"=>"1", # 課稅類別，僅可帶入'1'、'2'、'3'、'9'
			"SalesAmount"=>"51800", # 發票金額
			"InvoiceRemark"=>"", # 備註
			"ItemName"=>"烏魚子櫻花蝦醬|烏魚子干貝醬|九降風烏魚子|波士頓生龍蝦|美洲生龍蝦|帝王蟹切盤|黃金鯧|蘇聯生干貝|特級花枝丸|大比目魚片|藍帶小白鯧|櫻花蝦香腸|飛魚卵香腸|無刺
虱目魚肚", # 商品名稱，如果超過一樣商品時請以｜(為半形不可使用全形)分隔
			"ItemCount"=>"1|1|1|1|1|1|1|1|1|1|1|1|1|1", # 商品數量，如果超過一樣商品時請以｜(為半形不可使用全形)分隔
			"ItemWord"=>"pic|pic|pic|pic|pic|pic|pic|pic|pic|pic|pic|pic|pic|pic", # 商品單位，如果超過一樣商品時請以｜(為半形不可使用全形)分隔
			"ItemPrice"=>"3180|3180|3180|4880|4880|3600|3000|3180|3180|3180|4880|4880|3600|3000", # 商品價格，如果超過一樣商品時請以｜(為半形不可使用全形)分隔
			"ItemTaxType"=>"", # 商品課稅別，如果超過一樣商品時請以｜(為半形不可使用全形)分隔，如果TaxType為9請帶值，其餘為空
			"ItemAmount"=>"3180|3180|3180|4880|4880|3600|3000|3180|3180|3180|4880|4880|3600|3000", # 商品合計，如果超過一樣商品時請以｜(為半形不可使用全形)分隔
			"ItemRemark"=>"備註|備註|備註|備註|備註|備註|備註|備註|備註|備註|備註|備註|備註|備註", # 商品備註，如果超過一樣商品時請以｜(為半形不可使用全形)分隔
			"InvType"=>"07", # 字軌類別，、'07'一般稅額、'08'特種稅額
			"vat"=>"1" # 商品單價是否含稅，'1'為含稅價'、'0為未稅價
		}
		
		inv_issue = ECpayInvoice::InvoiceClientECPay.new # 將模組中的class實例化
		res = inv_issue.ecpay_invoice_issue(inv_issue_dict) # 對class中的對應的method傳入位置參數

		puts res # 將回傳結果列印出來
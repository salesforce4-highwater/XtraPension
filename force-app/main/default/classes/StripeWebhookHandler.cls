@RestResource(urlMapping='/StripeWebhookApi/*')
global class StripeWebhookHandler {

	private static final String XTRAPENSION_LINK = 'https://go.xtrapension.com/form/';
	private static final Map<String, String[]> PROJECT_NAME_BY_RELATED_PRODUCT_NAME = new Map<String, String[]>{
        'Basic'    => new String[]{'Deposit', 'Application', 'Monthly Updates'},
        'Standard' => new String[]{'Deposit', 'Application', 'Monthly Updates', 'Guidance on HMRC Reply'},
        'Premier'  => new String[]{'Deposit', 'Application', 'Monthly Updates', 'Guidance on HMRC Reply', 'Pension & Tax Advice'}
    };
	private static final String DESCRIPTION = 'Registration MOTO';
	private static final String ACOUNT_RECORD_TYPE_NAME = 'Business_Account';
	private static final String PERSON_ACCOUNT_RECORD_TYPE_ID = '0127R000000bwcXQAQ';


	@HttpPost
    global static String invokeRestResponse() {
		RestRequest request = RestContext.request;
		Map<String, Object> eventData         = (Map<String, Object>) JSON.deserializeUntyped(request.requestBody.toString());
		Map<String, Object> objectData        = (Map<String, Object>) eventData.get('data');
		Map<String, Object> paymentIntentData = (Map<String, Object>) objectData.get('object');
		PaymentIntentWrapper paymentIntent    = (PaymentIntentWrapper) JSON.deserialize(JSON.serialize(paymentIntentData), PaymentIntentWrapper.class);
		Integer amount                        = paymentIntent.amount/100;
		String descriptionData                = paymentIntent.description;
		if (descriptionData.equals(DESCRIPTION)) {
			String customerData = StripeApiService.getCustomerData(paymentIntent?.customer);
			if (customerData == 'Error') {
				return 'Didn\'t find customer';
			}
			Map<String, Object> customer = (Map<String, Object>) JSON.deserializeUntyped(customerData);

			Account account = new Account();
        	String phoneDuplicateFinder = '%' + paymentIntent?.shipping?.phone?.substring(1, paymentIntent?.shipping?.phone?.length() - 4) + '%';
        	String personContactId = '';

        	account = new Account(
				LastName                = paymentIntent?.shipping?.name,
            	PersonEmail             = (String) customer.get('email'),
            	PersonMobilePhone       = paymentIntent?.shipping?.phone,
            	PersonMailingCity       = paymentIntent?.shipping?.address?.city,
            	PersonMailingCountry    = paymentIntent?.shipping?.address?.country,
            	PersonMailingState      = paymentIntent?.shipping?.address?.state,
            	PersonMailingPostalCode = paymentIntent?.shipping?.address?.postal_code,
            	PersonMailingStreet     = paymentIntent?.shipping?.address?.line1,
            	Mailing_Country__c      = CountryCodeHelper.getCountryNameByIsoCode(paymentIntent?.shipping?.address?.country),
            	Mailing_State__c        = CountryCodeHelper.getCountryStateNameByIsoCode(
											paymentIntent?.shipping?.address?.country,
											paymentIntent?.shipping?.address?.state)
            );
			if (!Test.isRunningTest()) {
				account.RecordTypeId = PERSON_ACCOUNT_RECORD_TYPE_ID;
			}
        	insert account;
			List<Contact> currentContact = [
				SELECT
					Id,
					AccountId
				FROM Contact
				WHERE AccountId = :account.Id
				LIMIT 1
			];
			if (!currentContact.isEmpty()) {
				personContactId = currentContact[0].Id;
			}

			List<Agent__c> mainAgent = [
				SELECT
					Id,
					Name
				FROM Agent__c
			];
			Id agentId = mainAgent.size() == 0 ? null : mainAgent[0].Id;

			String fullName = paymentIntent?.shipping?.name.trim();
			String lastName = fullName.substringAfterLast(' ');
			String firstName = fullName.removeEnd(lastName).trim();

			Application__c application = new Application__c(
				First_Name__c                         = firstName,
				Second_Name__c                        = lastName,
				Expiry_Date__c                        = Datetime.now().addYears(1),
				Package_Name__c                       = 'Standard',
				Payment_Method__c                     = paymentIntent?.payment_method,
				Stripe_Customer_Id__c                 = paymentIntent?.customer,
				Status__c                             = 'Form In Progress',
				Is_Payment_Completed__c               = true,
				Step__c                               = 'Personal Details',
				Stripe_Transaction_Id__c              = paymentIntent?.id,
				Contact__c                            = personContactId,
				Personal_Details_Form_Link__c         = XTRAPENSION_LINK + paymentIntent?.id,
				Amount__c                             = paymentIntent?.amount != null ?
															paymentIntent?.amount / 100 : 0,
				Last_UK_Home_Address__CountryCode__s  = 'GB',
				Related_Contact_Phone__c              = account.PersonMobilePhone,
				Email__c                              = account.PersonEmail,
				Live_In_The_EU__c                     = amount == 100 ? true : false,
				Agent__c                              = mainAgent.size() == 0 ? null : mainAgent[0].Id,
				Pay_Voluntary_Contribution_At__c      = 'Class 2'
			);
			insert application;

			List<PriceBookEntry> priceBookEntries = new List<PriceBookEntry>();
            if (!Test.isRunningTest()) {
                priceBookEntries = [
                    SELECT
                        Id,
                        Product2Id,
                        Product2.Name,
                        Pricebook2Id,
                        Pricebook2.IsStandard,
                        UnitPrice
                    FROM PriceBookEntry
                    WHERE Product2.Name IN :PROJECT_NAME_BY_RELATED_PRODUCT_NAME.get(application.Package_Name__c) AND
                          Pricebook2.IsStandard = :application.Live_In_The_EU__c
                ];
            } else {
                priceBookEntries = [
                    SELECT
                        Id,
                        Product2Id,
                        Product2.Name,
                        Pricebook2Id,
                        Pricebook2.IsStandard,
                        UnitPrice
                    FROM PriceBookEntry
                    WHERE Product2.Name IN :PROJECT_NAME_BY_RELATED_PRODUCT_NAME.get(application.Package_Name__c)
                ];
            }
            if (priceBookEntries.isEmpty()) {
                    return 'Empty pricebook entry';
            }
            Map<String, PriceBookEntry> productNameByPricebookEntry = new Map<String, PriceBookEntry>();
            for (PriceBookEntry price : priceBookEntries) {
                productNameByPricebookEntry.put(price.Product2.Name, price);
			}
            Order newOrder = new Order(
                Status         = 'Draft',
                EffectiveDate  = Date.today(),
                Pricebook2Id   = priceBookEntries[0].Pricebook2Id,
                AccountId      = account.Id,
                Application__c = application.Id
            );
            insert newOrder;
            if (!priceBookEntries.isEmpty()) {
                List<Payment__c> newPayments = new List<Payment__c>();
                List<OrderItem> newOrderItems = new List<OrderItem>();
                for (String productName : PROJECT_NAME_BY_RELATED_PRODUCT_NAME.get(application.Package_Name__c)) {
                    PriceBookEntry entry = productNameByPricebookEntry.get(productName);
                     	newOrderItems.add(
                            new OrderItem(
		                        Product2Id       = entry.Product2Id,
		                        OrderId          = newOrder.Id,
		                        PricebookEntryId = entry.Id,
		                        Quantity         = /*entry.Product2.Name == 'Monthly Updates' ? 8 : */1,
                                UnitPrice        = entry.UnitPrice
		                    )
                    );
                    // if (productName == 'Monthly Updates') {
                    //     for (Integer i = 0; i < 8; i++) {
                    //         newPayments.add(
                    //             new Payment__c (
                    //                 Amount__c         = entry.UnitPrice,
                    //                 Product__c        = entry.Product2Id,
                    //                 Status__c         = 'Draft',
                    //                 Payment_Method__c = application.Payment_Method__c,
                    //                 Customer_Id__c    = application.Stripe_Customer_Id__c,
                    //                 Order__c          = newOrder.Id,
                    //                 Application__c    = application.Id
                    //             )
                    //         );
                    //     }
                    //     continue;
                    // }
                    newPayments.add(
                        new Payment__c (
                            Amount__c         = entry.UnitPrice,
                            Product__c        = entry.Product2Id,
                            Status__c         = entry.Product2.Name != 'Deposit' ? 'Draft' : 'Paid',
                            Payment_Method__c = application.Payment_Method__c,
                            Customer_Id__c    = application.Stripe_Customer_Id__c,
                            Order__c          = newOrder.Id,
                            Application__c    = application.Id,
                            Payment_Date__c   = entry.Product2.Name == 'Deposit' ? Date.today() : null
                        )
                    );
                }
                List<Sobject> newSobjects = new List<Sobject>();
                newSobjects.addAll(newOrderItems);
                newSobjects.addAll(newPayments);
                if (newSobjects != null) {
                    insert newSobjects;
                }
			}
			return 'Success';
		}
		return 'Not MOTO Payment';
	}

	private class PaymentIntentWrapper {
		private String id;
		private Integer amount;
		private String description;
		private ShippingDataWrapper shipping;
		private String customer;
		private String payment_method;
	}

	private class ShippingDataWrapper {
		private String name;
		private String phone;
		private AddessData address;
	}

	private class AddessData {
		private String city;
		private String country;
		private String line1;
		private String postal_code;
		private String state;
	}
}
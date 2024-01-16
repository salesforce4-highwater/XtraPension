public with sharing class ApplicationManagerHandler {

    private static final String XTRAPENSION_LINK = 'https://xtrapension.herokuapp.com/form/';
    private static final String XTRAPENSION_PRODUCT_NAME = 'XtraPension Application';
    private static final Map<String, String[]> PROJECT_NAME_BY_RELATED_PRODUCT_NAME = new Map<String, String[]> {
    'Basic'    => new String[]{'Deposit', 'Application'/*, 'Monthly Updates'*/},
        'Standard' => new String[]{'Deposit', 'Application'/*, 'Monthly Updates'*/, 'Guidance on HMRC Reply'},
        'Premier'  => new String[]{'Deposit', 'Application'/*, 'Monthly Updates'*/, 'Guidance on HMRC Reply', 'Pension & Tax Advice'}
    };
    private static final Map<String, String> COUNTRY_CODE_BY_NAME = CountryCodeHelper.getCountryCodeByCountryName();

    public static Map<String, Object> createApplication(ApplicationManager.RequestDataWrapper applicationData) {

        if (applicationData != null) {
            Map<String, Object> result = new Map<String, Object>();
            try {
                Account account = new Account();
                String phoneDuplicateFinder = '%' + applicationData.phone.substring(1, applicationData.phone.length() - 4) + '%';
                String personContactId = '';
                account = new Account(
                    //add logic check if only 1 word
                    //add line 2 from form
                    LastName                = applicationData?.name,
                    PersonEmail             = applicationData?.email,
                    PersonMobilePhone       = applicationData?.phone,
                    PersonMailingCity       = applicationData.address?.city,
                    PersonMailingCountry    = applicationData.address?.country,
                    PersonMailingState      = applicationData.address?.state,
                    PersonMailingPostalCode = applicationData.address?.postal_code,
                    PersonMailingStreet     = applicationData.address?.line1,
                    Mailing_Country__c      = CountryCodeHelper.getCountryNameByIsoCode(applicationData?.address?.country),
                    Mailing_State__c        = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                applicationData?.address?.country,
                                                applicationData?.address?.state)
                );
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

                Application__c application = new Application__c(
                    First_Name__c                         = applicationData?.firstName,
                    Second_Name__c                        = applicationData?.lastName,
                    Expiry_Date__c                        = Datetime.now().addYears(1),
                    Package_Name__c                       = applicationData?.packageName,
                    Payment_Method__c                     = applicationData?.paymentMethod,
                    Stripe_Customer_Id__c                 = applicationData?.customer,
                    Status__c                             = 'Form In Progress',
                    Is_Payment_Completed__c               = true,
                    Step__c                               = 'Personal Details',
                    Stripe_Transaction_Id__c              = applicationData?.id,
                    Contact__c                            = personContactId,
                    Personal_Details_Form_Link__c         = XTRAPENSION_LINK + applicationData?.id,
                    Amount__c                             = applicationData?.amount != null ?  applicationData?.amount / 100 : 0,
                    Last_UK_Home_Address__CountryCode__s  = 'GB',
                    Related_Contact_Phone__c              = account.PersonMobilePhone,
                    Email__c                              = account.PersonEmail,
                    Live_In_The_EU__c                     = applicationData?.tax,
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
                        WHERE Product2.Name IN :PROJECT_NAME_BY_RELATED_PRODUCT_NAME.get(applicationData.packageName) AND
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
                        WHERE Product2.Name IN :PROJECT_NAME_BY_RELATED_PRODUCT_NAME.get(applicationData.packageName)
                    ];
                }
                if (priceBookEntries.isEmpty()) {
                    result.put('status', 'Error');
                    result.put('errorBody', 'PriceBookEntries are empty');
                    return result;
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
                        /*if (productName == 'Monthly Updates') {
                            for (Integer i = 0; i < 8; i++) {
                                newPayments.add(
                                    new Payment__c (
                                        Amount__c         = entry.UnitPrice,
                                        Product__c        = entry.Product2Id,
                                        Status__c         = 'Draft',
                                        Payment_Method__c = application.Payment_Method__c,
                                        Customer_Id__c    = application.Stripe_Customer_Id__c,
                                        Order__c          = newOrder.Id,
                                        Application__c    = application.Id
                                    )
                                );
                            }
                            continue;
                        }*/
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

                Map<String, Id> productNameById = new Map<String, Id>();
                result.put('status', 'Success');
            } catch (Exception e) {
                //add log record ?
                result.put('status', 'Error');
                result.put('errorBody', e.getLineNumber() + '-' + e.getMessage());
            }
            return result;
        }

        return new Map<String, Object>();
    }

    public static Map<String, Object> setApplicationPersonalDetails(ApplicationManager.ApplicationPersonalStepWrapper applicationData, String stripeId) {
        Map<String, Object> result = new Map<String, Object>();
        Datetime todayDateTime = Datetime.now();
        String queryLine = 'SELECT ' +
                                'Id, ' +
                                'Salutation__c, ' +
                                'First_Name__c, ' +
                                'Second_Name__c, ' +
                                'Date_Of_Birth__c, ' +
                                'National_Insurance_Number__c, ' +
                                'Work_Or_Pay_UK_National_Insurance__c, ' +
                                'Private_UK_Pension__c, ' +
                                'Approx_Value_Of_UK_Pension__c, ' +
                                'Previous_UK_Address_1__City__s, ' +
                                'Previous_UK_Address_1__CountryCode__s, ' +
                                'Previous_UK_Address_1__PostalCode__s, ' +
                                'Previous_UK_Address_1__StateCode__s, ' +
                                'Previous_UK_Address_1__Street__s, ' +
                                'Previous_UK_Address_Start_Date_1__c, ' +
                                'Previous_UK_Address_End_Date_1__c, ' +
                                'Previous_UK_Address_2__City__s, ' +
                                'Previous_UK_Address_2__CountryCode__s, ' +
                                'Previous_UK_Address_2__PostalCode__s, ' +
                                'Previous_UK_Address_2__StateCode__s, ' +
                                'Previous_UK_Address_2__Street__s, ' +
                                'Previous_UK_Address_Start_Date_2__c, ' +
                                'Previous_UK_Address_End_Date_2__c, ' +
                                'Previous_UK_Address_3__City__s, ' +
                                'Previous_UK_Address_3__CountryCode__s, ' +
                                'Previous_UK_Address_3__PostalCode__s, ' +
                                'Previous_UK_Address_3__StateCode__s, ' +
                                'Previous_UK_Address_3__Street__s, ' +
                                'Previous_UK_Address_Start_Date_3__c, ' +
                                'Previous_UK_Address_End_Date_3__c, ' +
                                'Current_Occupation__c, ' +
                                'Current_Address_Abroad__City__s, ' +
                                'Current_Address_Abroad__Street__s, ' +
                                'Current_Address_Abroad__StateCode__s, ' +
                                'Current_Address_Abroad__CountryCode__s, ' +
                                'Current_Address_Abroad__PostalCode__s, ' +
                                'Last_UK_Home_Address__City__s, ' +
                                'Last_UK_Home_Address__CountryCode__s, ' +
                                'Last_UK_Home_Address__Street__s, ' +
                                'Last_UK_Home_Address__StateCode__s, ' +
                                'Last_UK_Home_Address__PostalCode__s, ' +
                                'Step__c, ' +
                                'Is_Know_National_Insurance_Number__c ' +
                            'FROM Application__c ' +
                            'WHERE Stripe_Transaction_Id__c = :stripeId' +
                                ' AND Expiry_Date__c > :todayDateTime' +
                            ' LIMIT 1 ';
        Application__c app = Database.query(queryLine);
        if (app == null) {
            result.put('error', 'Don\'t found application');
        }
        try {
            app.Salutation__c                          = applicationData?.salutation;
            app.First_Name__c                          = applicationData?.firstName;
            app.Second_Name__c                         = applicationData?.secondName;
            app.Date_Of_Birth__c                       = Date.valueOf(applicationData?.dateOfBirth);
            app.National_Insurance_Number__c           = applicationData?.insuranceNumber?.replaceAll('(\\s+)', '');
            app.Work_Or_Pay_UK_National_Insurance__c   = applicationData?.workOrPayUKNationalInsurance;
            app.Private_UK_Pension__c                  = applicationData?.privateUKPension;
            app.Approx_Value_Of_UK_Pension__c          = applicationData?.approxValue;
            app.Current_Occupation__c                  = applicationData?.currentOccupation;
            app.Current_Address_Abroad__City__s        = applicationData?.currentAddressAbroad?.city;
            app.Current_Address_Abroad__Street__s      = applicationData?.currentAddressAbroad?.street;
            app.Current_Address_Abroad__StateCode__s   = applicationData?.currentAddressAbroad?.state;
            app.Current_Address_Abroad__CountryCode__s = applicationData?.currentAddressAbroad?.country;
            app.Current_Address_Abroad__PostalCode__s  = applicationData?.currentAddressAbroad?.postcode;
            app.Current_Address_Abroad_Country__c      = CountryCodeHelper.getCountryNameByIsoCode(applicationData?.currentAddressAbroad?.country);
            app.Current_Address_Abroad_State__c        = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                            applicationData?.currentAddressAbroad?.country,
                                                            applicationData?.currentAddressAbroad?.state);
            app.Last_UK_Home_Address__City__s          = applicationData?.lastUKHomeAddress?.city;
            app.Last_UK_Home_Address__Street__s        = applicationData?.lastUKHomeAddress?.street;
            app.Last_UK_Home_Address__StateCode__s     = applicationData?.lastUKHomeAddress?.state;
            app.Last_UK_Home_Address__PostalCode__s    = applicationData?.lastUKHomeAddress?.postcode;
            app.Last_UK_Home_Address_Country__c        = CountryCodeHelper.getCountryNameByIsoCode(applicationData?.lastUKHomeAddress?.country);
            app.Last_UK_Home_Address_State__c          = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                            applicationData?.lastUKHomeAddress?.country,
                                                            applicationData?.lastUKHomeAddress?.state);
            app.Step__c                                = 'Relationship';
            app.Is_Know_National_Insurance_Number__c   = applicationData?.isKnowNationalInsuranceNumber;
            app.Previous_UK_Address_1__City__s         = applicationData?.lastUKHomeAddress?.city;
            app.Previous_UK_Address_1__CountryCode__s  = applicationData?.lastUKHomeAddress?.country;
            app.Previous_UK_Address_1__PostalCode__s   = applicationData?.lastUKHomeAddress?.postcode;
            app.Previous_UK_Address_1__StateCode__s    = applicationData?.lastUKHomeAddress?.state;
            app.Previous_UK_Address_1__Street__s       = applicationData?.lastUKHomeAddress?.street;
            app.Previous_UK_Address_Start_Date_1__c    = Date.valueOf(applicationData?.lastUKHomeAddress?.fromDate);
            app.Previous_UK_Address_End_Date_1__c      = Date.valueOf(applicationData?.lastUKHomeAddress?.toDate);
            app.Previous_UK_Address_2__City__s         = applicationData?.lastUKHomeAddress2?.city != null ? applicationData?.lastUKHomeAddress2?.city : null;
            app.Previous_UK_Address_2__CountryCode__s  = applicationData?.lastUKHomeAddress2?.country != null ? applicationData?.lastUKHomeAddress2?.country : null;
            app.Previous_UK_Address_2__PostalCode__s   = applicationData?.lastUKHomeAddress2?.postcode != null ? applicationData?.lastUKHomeAddress2?.postcode : null;
            app.Previous_UK_Address_2__StateCode__s    = applicationData?.lastUKHomeAddress2?.state != null ? applicationData?.lastUKHomeAddress2?.state : null;
            app.Previous_UK_Address_2__Street__s       = applicationData?.lastUKHomeAddress2?.street != null ? applicationData?.lastUKHomeAddress2?.street : null;
            app.Previous_UK_Address_Start_Date_2__c    = Date.valueOf(applicationData?.lastUKHomeAddress2?.fromDate);
            app.Previous_UK_Address_End_Date_2__c      = Date.valueOf(applicationData?.lastUKHomeAddress2?.toDate);
            app.Previous_UK_Address_3__City__s         = applicationData?.lastUKHomeAddress3?.city != null ? applicationData?.lastUKHomeAddress3?.city : null;
            app.Previous_UK_Address_3__CountryCode__s  = applicationData?.lastUKHomeAddress3?.country  != null ? applicationData?.lastUKHomeAddress3?.country : null;
            app.Previous_UK_Address_3__PostalCode__s   = applicationData?.lastUKHomeAddress3?.postcode  != null ? applicationData?.lastUKHomeAddress3?.postcode : null;
            app.Previous_UK_Address_3__StateCode__s    = applicationData?.lastUKHomeAddress3?.state != null ? applicationData?.lastUKHomeAddress3?.state : null;
            app.Previous_UK_Address_3__Street__s       = applicationData?.lastUKHomeAddress3?.street != null ? applicationData?.lastUKHomeAddress3?.street : null;
            app.Previous_UK_Address_Start_Date_3__c    = Date.valueOf(applicationData?.lastUKHomeAddress3?.fromDate);
            app.Previous_UK_Address_End_Date_3__c      = Date.valueOf(applicationData?.lastUKHomeAddress3?.toDate);
            app.Previous_UK_Address_1_Country__c       = CountryCodeHelper.getCountryNameByIsoCode(applicationData?.lastUKHomeAddress?.country);
            app.Previous_UK_Address_2_Country__c       = CountryCodeHelper.getCountryNameByIsoCode(applicationData?.lastUKHomeAddress2?.country);
            app.Previous_UK_Address_3_Country__c       = CountryCodeHelper.getCountryNameByIsoCode(applicationData?.lastUKHomeAddress3?.country);
            app.Previous_UK_Address1_State__c          = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                            applicationData?.lastUKHomeAddress?.country,
                                                            applicationData?.lastUKHomeAddress?.state);
            app.Previous_UK_Address2_State__c          = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                            applicationData?.lastUKHomeAddress2?.country,
                                                            applicationData?.lastUKHomeAddress2?.state);
            app.Previous_UK_Address3_State__c          = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                            applicationData?.lastUKHomeAddress3?.country,
                                                            applicationData?.lastUKHomeAddress3?.state);
            // for (Integer i = 1; i <= 5; i++) {
            //     if (applicationData?.previousUKAddress.size() >= i) {
            //         app.put('Previous_UK_Address_' + i + '__City__s', applicationData?.previousUKAddress[i-1].city);
            //         app.put('Previous_UK_Address_' + i + '__CountryCode__s', applicationData?.previousUKAddress[i-1].country);
            //         app.put('Previous_UK_Address_' + i + '__PostalCode__s', applicationData?.previousUKAddress[i-1].postcode);
            //         app.put('Previous_UK_Address_' + i + '__StateCode__s', applicationData?.previousUKAddress[i-1].state);
            //         app.put('Previous_UK_Address_' + i + '__Street__s', applicationData?.previousUKAddress[i-1].street);
            //         app.put('Previous_UK_Address_' + i + '_Country__c', CountryCodeHelper.getCountryNameByIsoCode(applicationData?.previousUKAddress[i-1].country));
            //         app.put('Previous_UK_Address' + i + '_State__c', CountryCodeHelper.getCountryStateNameByIsoCode(
            //                                                             applicationData?.previousUKAddress[i-1].country,
            //                                                             applicationData?.previousUKAddress[i-1].state));
            //     } else {
            //         app.put('Previous_UK_Address_' + i + '__City__s', null);
            //         app.put('Previous_UK_Address_' + i + '__CountryCode__s', null);
            //         app.put('Previous_UK_Address_' + i + '__PostalCode__s', null);
            //         app.put('Previous_UK_Address_' + i + '__StateCode__s', null);
            //         app.put('Previous_UK_Address_' + i + '__Street__s', null);
            //         app.put('Previous_UK_Address_' + i + '_Country__c', null);
            //         app.put('Previous_UK_Address' + i + '_State__c', null);
            //     }
            // }
            update app;
            result.put('status', 'Success');
        } catch (Exception ex) {
            result.put('status', 'Error');
            result.put('message', ex.getLineNumber() + '-' + ex.getMessage());
        }
        return result;
    }

    public static Map<String, Object> setApplicationRelationshipDetails(ApplicationManager.RelationshipStepWrapper requestData, String stripeId) {
        Map<String, Object> result = new Map<String, Object>();
        Application__c app = [
            SELECT
                Did_You_Change_Name__c,
                Date_Of_Marriage_Or_Civil_Partnership__c,
                Are_You_Divorced__c,
                Full_Maiden_Previous_Name__c,
                Are_You_Single__c,
                Divorce_Date__c,
                Step__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = :stripeId
                AND Expiry_Date__c > :Datetime.now()
            LIMIT 1
        ];
        if (app == null) {
            result.put('error', 'Don\'t found application');
        }
        try {
            app.Are_You_Single__c   = requestData?.single;
            app.Step__c             = 'UK Work';
            if (requestData?.single == true && requestData?.divorcedOrwidowed) {
                app.Did_You_Change_Name__c                   = false;
                app.Date_Of_Marriage_Or_Civil_Partnership__c = null;
                app.Full_Maiden_Previous_Name__c             = '';
                app.Are_You_Divorced__c                      = requestData?.divorcedOrwidowed;
                app.Divorce_Date__c                          = Date.valueOf(requestData?.exactDate);
            } else if (requestData?.single == true && !requestData?.divorcedOrwidowed) {
                app.Did_You_Change_Name__c                   = false;
                app.Date_Of_Marriage_Or_Civil_Partnership__c = null;
                app.Full_Maiden_Previous_Name__c             = '';
                app.Are_You_Divorced__c                      = requestData?.divorcedOrwidowed;
                app.Divorce_Date__c                          = null;
            } else {
                app.Are_You_Divorced__c                      = false;
                app.Divorce_Date__c                          = null;
                app.Did_You_Change_Name__c                   = requestData?.changeYouName;
                app.Date_Of_Marriage_Or_Civil_Partnership__c = Date.valueOf(requestData?.dateOfMarriedOrPartnership);
                app.Full_Maiden_Previous_Name__c             = requestData?.fullMaindenOrPreviousName;
            }
            update app;
            result.put('status', 'Success');
        } catch (Exception ex) {
            result.put('status', 'Error');
            result.put('message', ex.getLineNumber() + '-' + ex.getMessage());
        }
        return result;
    }

    public static Map<String, Object> setApplicationUkWorkDetails(ApplicationManager.UkWorkStepWrapper requestData, String stripeId) {
        Map<String, Object> result = new Map<String, Object>();
        Application__c app = [
            SELECT
                Id,
                Type_Of_Employment__c,
                Date_Of_Leaving_Last_UK__c,
                Years_Of_Work_In_The_UK__c,
                Step__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = :stripeId
                AND Expiry_Date__c > :Datetime.now()
            LIMIT 1
        ];
        List<Employer__c> relatedEmployers = [
            SELECT
                Application__r.Id,
                Type__c
            FROM Employer__c
            WHERE Application__r.Id = :app.Id
                AND Type__c = 'UK Work'
        ];
        try {
            delete relatedEmployers;
            List<SObject> currentSobjects = new List<SObject>();
            app.Date_Of_Leaving_Last_UK__c               = Date.valueOf(requestData?.endDateOfLastUKEmployer);
            app.Years_Of_Work_In_The_UK__c               = requestData?.yearsWorkInUK;
            app.Step__c                                  = 'Work After UK';
            app.Type_Of_Employment__c                    = requestData?.workInUKBeforeLeaving;
            app.Last_UK_Employer_Name__c                 = requestData?.nameOfLastUKEmployer;
            app.Last_UK_Employer_Start_Date__c           = Date.valueOf(requestData?.startDateOfLastUKEmployer);
            app.Last_UK_Employer_End_Date__c             = Date.valueOf(requestData?.endDateOfLastUKEmployer);
            app.Last_UK_Employer_Address__City__s        = requestData?.workInUKBeforeLeaving == 'Employed' ? requestData?.lastUKEmployerAddress?.city : null;
            app.Last_UK_Employer_Address__CountryCode__s = requestData?.workInUKBeforeLeaving == 'Employed' ? requestData?.lastUKEmployerAddress?.country : null;
            app.Last_UK_Employer_Address__StateCode__s   = requestData?.workInUKBeforeLeaving == 'Employed' ? requestData?.lastUKEmployerAddress?.state : null;
            app.Last_UK_Employer_Address__Street__s      = requestData?.workInUKBeforeLeaving == 'Employed' ? requestData?.lastUKEmployerAddress?.street : null;
            app.Last_UK_Employer_Address__PostalCode__s  = requestData?.workInUKBeforeLeaving == 'Employed' ? requestData?.lastUKEmployerAddress?.postcode : null;
            app.Last_UK_Employer_Address_Country__c      = requestData?.workInUKBeforeLeaving == 'Employed' ?
                                                                CountryCodeHelper.getCountryNameByIsoCode(requestData?.lastUKEmployerAddress?.country):
                                                                null;
            app.Last_UK_Employer_Address_State__c        = requestData?.workInUKBeforeLeaving == 'Employed' ?
                                                                CountryCodeHelper.getCountryStateNameByIsoCode(
                                                                    requestData?.lastUKEmployerAddress?.country,
                                                                    requestData?.lastUKEmployerAddress?.state)
                                                                : null;

            currentSobjects.add(app);
            if(requestData?.workInUKBeforeLeaving == 'Employed') {
                Employer__c newEmployer = new Employer__c(
                    Employer_Name__c                  = requestData?.nameOfLastUKEmployer,
                    Start_Date__c                     = Date.valueOf(requestData?.startDateOfLastUKEmployer),
                    End_Date__c                       = Date.valueOf(requestData?.endDateOfLastUKEmployer),
                    Employers_Address__City__s        = requestData?.lastUKEmployerAddress?.city,
                    Employers_Address__CountryCode__s = requestData?.lastUKEmployerAddress?.country,
                    Employers_Address__StateCode__s   = requestData?.lastUKEmployerAddress?.state,
                    Employers_Address__Street__s      = requestData?.lastUKEmployerAddress?.street,
                    Employers_Address__PostalCode__s  = requestData?.lastUKEmployerAddress?.postcode,
                    Application__c                    = app.Id,
                    Type__c                           = 'UK Work',
                    Type_Of_UK_Employment__c          = 'Employed',
                    Employers_Address_Country__c      = CountryCodeHelper.getCountryNameByIsoCode(requestData?.lastUKEmployerAddress?.country),
                    Employers_Address_State__c        = CountryCodeHelper.getCountryStateNameByIsoCode(
                                                            requestData?.lastUKEmployerAddress?.country,
                                                            requestData?.lastUKEmployerAddress?.state)
                );
                currentSobjects.add(newEmployer);
            } else if(requestData?.workInUKBeforeLeaving == 'Self-Employed') {
                Employer__c newEmployer = new Employer__c(
                    Employer_Name__c                  = requestData?.nameOfLastUKEmployer,
                    Start_Date__c                     = Date.valueOf(requestData?.startDateOfLastUKEmployer),
                    End_Date__c                       = Date.valueOf(requestData?.endDateOfLastUKEmployer),
                    Application__c                    = app.Id,
                    Type__c                           = 'UK Work',
                    Type_Of_UK_Employment__c          = 'Self-Employed'
                );
                currentSobjects.add(newEmployer);
            } else if(requestData?.workInUKBeforeLeaving == 'Unemployed') {
                Employer__c newEmployer = new Employer__c(
                    Employer_Name__c                  = requestData?.nameOfLastUKEmployer,
                    Start_Date__c                     = Date.valueOf(requestData?.startDateOfLastUKEmployer),
                    End_Date__c                       = Date.valueOf(requestData?.endDateOfLastUKEmployer),
                    Application__c                    = app.Id,
                    Type__c                           = 'UK Work',
                    Type_Of_UK_Employment__c          = 'Unemployed'
                );
                currentSobjects.add(newEmployer);
            }
            upsert currentSobjects;
            result.put('status', 'Success');
        } catch (Exception ex) {
            result.put('status', 'Error');
            result.put('message', ex.getLineNumber() + '-' + ex.getMessage());
        }
        return result;
    }

    public static Map<String, Object> setApplicationWorkAfterUKDetails(ApplicationManager.WorkAfterUKStepWrapper requestData, String stripeId) {
        Map<String, Object> result = new Map<String, Object>();
        Application__c app = [
            SELECT
                Id,
                Step__c,
                Abroad_Employer_Name1__c,
                Abroad_Employer_Start_Date1__c,
                Abroad_Employer_End_Date1__c,
                Abroad_Employer_Address1__City__s,
                Abroad_Employer_Address1__CountryCode__s,
                Abroad_Employer_Address1__StateCode__s,
                Abroad_Employer_Address1__Street__s,
                Abroad_Employer_Address1__PostalCode__s,
                Abroad_Employer_Address1_Country__c,
                Abroad_Employer_Address1_State__c,
                Career_Break_Employer_Start_Date1__c,
                Career_Break_Employer_End_Date1__c,
                Self_Employed_Start_Date1__c,
                Self_Employed_End_Date1__c,
                SelfEmployment_Employment_Abroad__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = :stripeId
                AND Expiry_Date__c > :Datetime.now()
            LIMIT 1
        ];
        List<Employer__c> relatedEmployers = [
            SELECT
                Application__r.Id,
                Type__c
            FROM Employer__c
            WHERE Application__r.Id = :app.Id
                AND Type__c = 'Work After UK'
        ];
        try {
            if (!relatedEmployers.isEmpty()) {
                delete relatedEmployers;
            }
            app.put('Abroad_Employer_Name1__c', null);
            app.put('Abroad_Employer_Start_Date1__c', null);
            app.put('Abroad_Employer_End_Date1__c', null);
            app.put('Abroad_Employer_Address1__City__s', null);
            app.put('Abroad_Employer_Address1__CountryCode__s', null);
            app.put('Abroad_Employer_Address1__StateCode__s', null);
            app.put('Abroad_Employer_Address1__Street__s', null);
            app.put('Abroad_Employer_Address1__PostalCode__s', null);
            app.put('Abroad_Employer_Address1_Country__c', null);
            app.put('Abroad_Employer_Address1_State__c', null);
            app.put('Career_Break_Employer_Start_Date1__c', null);
            app.put('Career_Break_Employer_End_Date1__c', null);
            app.put('Self_Employed_Start_Date1__c', null);
            app.put('Self_Employed_End_Date1__c', null);
            app.put('Self_Employed_End_Date1__c', null);
            app.put('SelfEmployment_Employment_Abroad__c', null);
            update app;
            List<SObject> newEmployers = new List<SObject>();
            Employer__c firstEmployer;
            if (requestData?.workAfterUK != null) {
                for (ApplicationManager.AfterUKEmployerWrapper employer : requestData.workAfterUK) {
                    String countryName = CountryCodeHelper.getCountryNameByIsoCode(employer?.country);
                    String stateName   = CountryCodeHelper.getCountryStateNameByIsoCode(employer?.country, employer?.state);
                    if (employer?.afterLeftTheUK == 'Employed') {
                        Employer__c newEmployer = new Employer__c(
                            Employer_Name__c                  = employer?.nameOfYourEmployerAbroad,
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Employers_Address__City__s        = employer?.city,
                            Employers_Address__CountryCode__s = employer?.country,
                            Employers_Address__StateCode__s   = employer?.state,
                            Employers_Address__Street__s      = employer?.street,
                            Employers_Address__PostalCode__s  = employer?.postcode,
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Employers_Address_Country__c      = countryName,
                            Employers_Address_State__c        = stateName,
                            Type_Of_After_UK_Employment__c    = 'Employed',
                            Is_First_Employer__c              = firstEmployer == null ? true : false
                        );
                        if (app.Abroad_Employer_Name1__c == null && firstEmployer == null) {
                            app.put('Abroad_Start_Date__c', Date.valueOf(employer?.startDate));
                            app.put('Abroad_Employer_Name1__c', employer?.nameOfYourEmployerAbroad);
                            app.put('Abroad_Employer_Start_Date1__c', Date.valueOf(employer?.startDate));
                            app.put('Abroad_Employer_End_Date1__c', Date.valueOf(employer?.endDate));
                            app.put('Abroad_Employer_Address1__City__s', employer?.city);
                            app.put('Abroad_Employer_Address1__CountryCode__s', employer?.country);
                            app.put('Abroad_Employer_Address1__StateCode__s', employer?.state);
                            app.put('Abroad_Employer_Address1__Street__s', employer?.street);
                            app.put('Abroad_Employer_Address1__PostalCode__s',  employer?.postcode);
                            app.put('Abroad_Employer_Address1_Country__c', countryName);
                            app.put('Abroad_Employer_Address1_State__c', stateName);
                            app.put('SelfEmployment_Employment_Abroad__c', 'Employed');
                            firstEmployer = newEmployer;
                        }
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Career Break') {
                        Employer__c newEmployer = new Employer__c(
                            Employer_Name__c                  = employer?.nameOfYourEmployerAbroad,
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Employers_Address__City__s        = employer?.city,
                            Employers_Address__CountryCode__s = employer?.country,
                            Employers_Address__StateCode__s   = employer?.state,
                            Employers_Address__Street__s      = employer?.street,
                            Employers_Address__PostalCode__s  = employer?.postcode,
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Employers_Address_Country__c      = countryName,
                            Employers_Address_State__c        = stateName,
                            Type_Of_After_UK_Employment__c    = 'Career Break'
                        );
                        if (app.Career_Break_Employer_Start_Date1__c == null) {
                            app.put('Career_Break_Employer_Start_Date1__c', Date.valueOf(employer?.startDate));
                            app.put('Career_Break_Employer_End_Date1__c', Date.valueOf(employer?.endDate));
                        }
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Self-Employed') {
                        Employer__c newEmployer = new Employer__c(
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Type_Of_After_UK_Employment__c    = 'Self-Employed',
                            Is_First_Employer__c              = firstEmployer == null ? true : false
                        );
                        if (app.Self_Employed_Start_Date1__c == null && firstEmployer == null) {
                            app.put('Self_Employed_Start_Date1__c', Date.valueOf(employer?.startDate));
                            app.put('Self_Employed_End_Date1__c', Date.valueOf(employer?.endDate));
                            app.put('Abroad_Start_Date__c', Date.valueOf(employer?.startDate));
                            app.put('SelfEmployment_Employment_Abroad__c', 'Self-employed');
                            firstEmployer = newEmployer;
                        }
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Unemployed') {
                        Employer__c newEmployer = new Employer__c(
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Type_Of_After_UK_Employment__c    = 'Unemployed'
                        );
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Family Carer') {
                        Employer__c newEmployer = new Employer__c(
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Type_Of_After_UK_Employment__c    = 'Family Carer'
                        );
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Homemaker') {
                        Employer__c newEmployer = new Employer__c(
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Type_Of_After_UK_Employment__c    = 'Homemaker'
                        );
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Disabled') {
                        Employer__c newEmployer = new Employer__c(
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Type_Of_After_UK_Employment__c    = 'Disabled'
                        );
                        newEmployers.add(newEmployer);
                    } else if (employer?.afterLeftTheUK == 'Retired') {
                        Employer__c newEmployer = new Employer__c(
                            Start_Date__c                     = Date.valueOf(employer?.startDate),
                            End_Date__c                       = Date.valueOf(employer?.endDate),
                            Application__c                    = app.Id,
                            Type__c                           = 'Work After UK',
                            Type_Of_After_UK_Employment__c    = 'Retired'
                        );
                        newEmployers.add(newEmployer);
                    }
                }
            }
            app.Step__c = 'Documents';
            newEmployers.add(app);
            upsert newEmployers;
            result.put('status', 'Success');
        } catch (Exception ex) {
            result.put('status', 'Error');
            result.put('message', ex.getLineNumber() + '-' + ex.getMessage());
        }
        return result;
    }

    public static Map<String, Object> setApplicationDocumentsDetails(ApplicationManager.DocumentsStepWrapper requestData, String stripeId) {
        Map<String, Object> result = new Map<String, Object>();
        Application__c app = [
            SELECT
                Id,
                Status__c,
                First_Name__c,
                Second_Name__c,
                Name
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = :stripeId
                AND Expiry_Date__c > :Datetime.now()
            LIMIT 1
        ];
        String idCurrentContentVersion = requestData?.statements;
        List<ContentDocumentLink> oldDocuments = [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.LatestPublishedVersionId,
                LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocument.Title LIKE '%UPLOAD%' AND
                  LinkedEntityId = :app.Id
        ];
        if (!oldDocuments.isEmpty()) {
            ContentDocumentLink lastVersionOfUploadDocument;
            for (ContentDocumentLink link : oldDocuments) {
                if (link.ContentDocument.LatestPublishedVersionId != idCurrentContentVersion &&
                    link.ContentDocument.Title.contains('ForSignature') &&
                    !link.ContentDocument.Title.contains('completed')) {
                    lastVersionOfUploadDocument = link;
                    break;
                }
            }
            if (lastVersionOfUploadDocument != null) {
                ContentDocument updateDocument = new ContentDocument();
                updateDocument.Id = lastVersionOfUploadDocument.ContentDocumentId;
                updateDocument.Title = lastVersionOfUploadDocument.ContentDocument.Title.replace('ForSignature', 'v' + (oldDocuments.size() - 1) + '.0');
                update updateDocument;

                List<ContentVersion> contentVersions = [
                    SELECT
                        Id,
                        Title,
                        FileType,
                        ContentSize,
                        ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :idCurrentContentVersion
                    LIMIT 1
                ];
                ContentVersion currentContentVersion = contentVersions[0];

                List<Application_Document__c> relatedApplicationDocuments = [
                    SELECT
                        File_Name__c
                    FROM Application_Document__c
                    WHERE Application__c = :app.Id AND
                          File_Name__c LIKE '%UPLOAD%'
                    LIMIT 1
                ];
                if (!relatedApplicationDocuments.isEmpty()) {
                    ContentDocumentLink conDocLinkUploadDoc = new ContentDocumentLink();
                    conDocLinkUploadDoc.LinkedEntityId = relatedApplicationDocuments[0].Id;
                    conDocLinkUploadDoc.ContentDocumentId = currentContentVersion.ContentDocumentId;
                    conDocLinkUploadDoc.shareType = 'V';
                    conDocLinkUploadDoc.Visibility = 'AllUsers';
                    insert conDocLinkUploadDoc;
                    app.Status__c = 'Form Completed';
                    update app;
                    result.put('status', 'Success');
                    result.put('isComplete', 'true');
                    return result;
                }
            } else {
                List<ContentVersion> contentVersions = [
                    SELECT
                        Id,
                        Title,
                        FileType,
                        ContentSize,
                        ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :idCurrentContentVersion
                    LIMIT 1
                ];
                ContentVersion currentContentVersion = contentVersions[0];
                try {
                    List<Application_Document__c> newApplicationDocuments = new List<Application_Document__c>();
                    newApplicationDocuments.add(new Application_Document__c(
                        Application__c = requestData?.applicationId,
                        File_Name__c   = app.First_Name__c + '_' + app.Second_Name__c + '_' + app.Name + '_UPLOAD_ForSignature',
                        File_Size__c   = currentContentVersion.ContentSize,
                        Large_File__c  = Integer.valueOf(currentContentVersion.ContentSize) > 6000000 ? true : false,
                        Status__c      = 'New',
                        Type__c        = 'CV'
                    ));
                    insert newApplicationDocuments;
                    List<SObject> newContentDocumentLinkAndApplication = new List<SObject>();
                    newContentDocumentLinkAndApplication.add(new ContentDocumentLink(
                        ContentDocumentId = currentContentVersion.ContentDocumentId,
                        LinkedEntityId    = newApplicationDocuments[0].Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                    app.Status__c             = 'Form Completed';
                    newContentDocumentLinkAndApplication.add(app);
                    upsert newContentDocumentLinkAndApplication;
                    result.put('status', 'Success');
                    result.put('isComplete', 'true');
                } catch (Exception ex) {
                    result.put('status', 'Error');
                    result.put('message', ex.getLineNumber() + '-' + ex.getMessage());
                }
            }
        }
        return result;
    }

    public static Map<String, Object> getApplication(String stripeId, Map<String, Object> result) {
        Datetime todayDateTime = Datetime.now();
        String queryLine =
            'SELECT ' +
                'Id, ' +
                'Name, ' +
                'Salutation__c, ' +
                'First_Name__c, ' +
                'Second_Name__c, ' +
                'Date_Of_Birth__c, ' +
                'National_Insurance_Number__c, ' +
                'Work_Or_Pay_UK_National_Insurance__c, ' +
                'Private_UK_Pension__c, ' +
                'Approx_Value_Of_UK_Pension__c, ' +
                'Current_Occupation__c, ' +
                'Current_Address_Abroad__City__s, ' +
                'Current_Address_Abroad__Street__s, ' +
                'Current_Address_Abroad__StateCode__s, ' +
                'Current_Address_Abroad__CountryCode__s, ' +
                'Current_Address_Abroad__PostalCode__s, ' +
                'Last_UK_Home_Address__City__s, ' +
                'Last_UK_Home_Address__CountryCode__s, ' +
                'Last_UK_Home_Address__Street__s, ' +
                'Last_UK_Home_Address__StateCode__s, ' +
                'Last_UK_Home_Address__PostalCode__s, ' +
                'Previous_UK_Address_1__City__s, ' +
                'Previous_UK_Address_1__CountryCode__s, ' +
                'Previous_UK_Address_1__PostalCode__s, ' +
                'Previous_UK_Address_1__StateCode__s, ' +
                'Previous_UK_Address_1__Street__s, ' +
                'Previous_UK_Address_Start_Date_1__c, ' +
                'Previous_UK_Address_End_Date_1__c, ' +
                'Previous_UK_Address_2__City__s, ' +
                'Previous_UK_Address_2__CountryCode__s, ' +
                'Previous_UK_Address_2__PostalCode__s, ' +
                'Previous_UK_Address_2__StateCode__s, ' +
                'Previous_UK_Address_2__Street__s, ' +
                'Previous_UK_Address_Start_Date_2__c, ' +
                'Previous_UK_Address_End_Date_2__c, ' +
                'Previous_UK_Address_3__City__s, ' +
                'Previous_UK_Address_3__CountryCode__s, ' +
                'Previous_UK_Address_3__PostalCode__s, ' +
                'Previous_UK_Address_3__StateCode__s, ' +
                'Previous_UK_Address_3__Street__s, ' +
                'Previous_UK_Address_Start_Date_3__c, ' +
                'Previous_UK_Address_End_Date_3__c, ' +
                'Abroad_Employer_Name1__c, ' +
                'Abroad_Employer_Start_Date1__c, ' +
                'Abroad_Employer_End_Date1__c, ' +
                'Abroad_Employer_Address1__City__s, ' +
                'Abroad_Employer_Address1__CountryCode__s, ' +
                'Abroad_Employer_Address1__StateCode__s, ' +
                'Abroad_Employer_Address1__Street__s, ' +
                'Abroad_Employer_Address1__PostalCode__s, ' +
                'Career_Break_Employer_Name1__c, ' +
                'Career_Break_Employer_Start_Date1__c, ' +
                'Career_Break_Employer_End_Date1__c, ' +
                'Career_Break_Employer_Address1__City__s, ' +
                'Career_Break_Employer_Address1__CountryCode__s, ' +
                'Career_Break_Employer_Address1__StateCode__s, ' +
                'Career_Break_Employer_Address1__Street__s, ' +
                'Career_Break_Employer_Address1__PostalCode__s, ' +
                'Self_Employed_Start_Date1__c, ' +
                'Self_Employed_End_Date1__c, ' +
                'Did_You_Change_Name__c, ' +
                'Date_Of_Marriage_Or_Civil_Partnership__c, ' +
                'Are_You_Divorced__c, ' +
                'Full_Maiden_Previous_Name__c, ' +
                'Are_You_Single__c, ' +
                'Type_Of_Employment__c, ' +
                'Date_Of_Leaving_Last_UK__c, ' +
                'Divorce_Date__c, ' +
                'Years_Of_Work_In_The_UK__c, ' +
                'Last_UK_Employer_Name__c, ' +
                'Last_UK_Employer_Start_Date__c, ' +
                'Last_UK_Employer_End_Date__c, ' +
                'Last_UK_Employer_Address__City__s, ' +
                'Last_UK_Employer_Address__CountryCode__s, ' +
                'Last_UK_Employer_Address__StateCode__s, ' +
                'Last_UK_Employer_Address__Street__s, ' +
                'Last_UK_Employer_Address__PostalCode__s, ' +
                    '(SELECT ' +
                        'Employer_Name__c, ' +
                        'Start_Date__c, ' +
                        'End_Date__c, ' +
                        'Employers_Address__City__s, ' +
                        'Employers_Address__CountryCode__s, ' +
                        'Employers_Address__StateCode__s, ' +
                        'Employers_Address__Street__s, ' +
                        'Employers_Address__PostalCode__s, ' +
                        'Type__c, ' +
                        'Type_Of_After_UK_Employment__c ' +
                    'FROM Employers__r), ' +
                'Step__c, ' +
                'Is_Know_National_Insurance_Number__c ' +
            'FROM Application__c ' +
            'WHERE Stripe_Transaction_Id__c =: stripeId ' +
                'AND Expiry_Date__c >: todayDateTime ' +
                'AND Status__c = \'Form In Progress\' ' +
            'LIMIT 1';
        try {
            Application__c app = Database.query(queryLine);
            if (app != null) {
                result.put('status', 'Success');
                result.put('currentStep', app.Step__c);
                result.put('formData', app);
            } else {
                result.put('error', 'Not found');
            }
        } catch (Exception ex) {
            result.put('error', ex.getMessage());
        }
        return result;

    }

    private static Employer__c getEmployerWithFirstStartDate(List<Employer__c> sortEmployers) {
        if (sortEmployers.isEmpty()) {
            return null;
        }
        Employer__c firstEmployer = sortEmployers[0];
        for (Integer i = 0; i < sortEmployers.size() - 1; i++) {
            firstEmployer = Date.valueOf(sortEmployers[i].Start_Date__c) < Date.valueOf(sortEmployers[i + 1].Start_Date__c) ?
                sortEmployers[i] :
                sortEmployers[i+1];
        }
        return firstEmployer;
    }

    public static Map<String, Object> getPaymentData(String paymentId) {
        Map<String, Object> result = new Map<String, Object>();
        List<Payment__c> payments = [
            SELECT
                Name,
                Application__r.Email__c,
                Amount__c
            FROM Payment__c
            WHERE Id = :paymentId
            LIMIT 1
        ];
        if (!payments.isEmpty()) {
            Payment__c currentPayment = payments[0];
            result.put('status', 'Success');
            result.put('email', currentPayment.Application__r.Email__c);
            result.put('amount', currentPayment.Amount__c * 100);
        } else {
            result.put('error', 'Not found');
        }
        return result;
    }

    public static Map<String, Object> changeStatusFailedPayment(ApplicationManager.PaymentDataWrapper requestData) {
        Map<String, Object> result = new Map<String, Object>();
        String paymentId     = requestData?.paymentId;
        String paymentMethod = requestData?.paymentMethod;
        List<Payment__c> payments = [
            SELECT
                Status__c,
                Payment_Method__c,
                Application__c,
                Application__r.Payment_Method__c,
                Payment_Date__c,
                Error_Message__c
            FROM Payment__c
            WHERE Id = :paymentId
            LIMIT 1
        ];
        if (!payments.isEmpty()) {
            List<SObject> updateRecords = new List<SObject>();
            Payment__c currentPayment = payments[0];
            StripeApiHandler.StripeAPIResponseWrapper requestPaymentMethodResult = StripeApiHandler.requestStripeApi(
				'payment_methods/' + paymentMethod,
				'GET',
				null
			);
			Map<String,Object> methodData = (Map<String,Object>) JSON.deserializeUntyped(requestPaymentMethodResult?.responseBody);
			Map<String,Object> cardData = (Map<String,Object>)methodData.get('card');
			currentPayment.Card_Data__c = cardData.get('brand') + ' - ' + cardData.get('last4');
            currentPayment.Status__c = 'Paid';
            currentPayment.Payment_Date__c = Date.today();
            currentPayment.Payment_Method__c = paymentMethod;
            currentPayment.Error_Message__c = '';
            updateRecords.add(currentPayment);
            Application__c relatedApplication = new Application__c();
            relatedApplication.Id = currentPayment.Application__c;
            relatedApplication.Payment_Method__c = paymentMethod;
            updateRecords.add(relatedApplication);

            List<Payment__c> relatedPayments = [
                SELECT
                    Payment_Method__c,
                    Application__c
                FROM Payment__c
                WHERE Application__c = :relatedApplication.Id AND
                      Id != :currentPayment.Id
            ];
            if (!relatedPayments.isEmpty()) {
                for (Payment__c pay : relatedPayments) {
                    pay.Payment_Method__c = paymentMethod;
                    updateRecords.add(pay);
                }
            }
            update updateRecords;
            result.put('status', 'Success');
        }
        return result;
    }
}
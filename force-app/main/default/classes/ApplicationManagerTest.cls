@isTest
public class ApplicationManagerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createProductsWithPrices();
        TestDataFactory.createTestCountry(true);
        Account account = TestDataFactory.createAccount(true);
        List<Contact> currentContact = [
            SELECT
                Id,
                AccountId
            FROM Contact
            WHERE AccountId = :account.Id
            LIMIT 1
        ];
        Id personContactId = currentContact[0].Id;
        Application__c testApplication = TestDataFactory.createApplication(personContactId, true);
        ContentVersion testContentVersion = TestDataFactory.createTestContentVersion(true);
        Id contDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testContentVersion.Id][0].ContentDocumentId;
        ContentDocumentLink conDocLink = new ContentDocumentLink();
        conDocLink.LinkedEntityId = testApplication.Id;
        conDocLink.ContentDocumentId = contDocId;
        insert conDocLink;
        Agent__c testAgent = TestDataFactory.createAgent(true);
        testApplication.Agent__c = testAgent.Id;
        update testApplication;
        Order order = TestDataFactory.createOrder(testApplication.Id, account.Id, true);
        TestDataFactory.createPayment(testApplication.Id, order.Id, true);
    }

    @IsTest static void createApplicationCase1(){
        Test.setMock(HttpCalloutMock.class, new PaymentMethodMock());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/create-app';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{ '+
            '"id": "12345784521",' +
            '"amount": "35000",' +
            '"email": "test.user@gmail.com",' +
            '"phone": "+1505123456123",' +
            '"name": "A-000001",' +
            '"firstName": "FirstName",' +
            '"lastName": "SecondName",' +
            '"packageName": "Premier",' +
            '"paymentMethod": "Test123456789Z",' +
            '"customer": "custome123456123457",' +
            '"tax": true,' +
            '"address": {' +
                '"line1": "1245 Test Street",' +
                '"line2": "Test",' +
                '"postal_code": "12345",' +
                '"state": "Washington",' +
                '"city": "Washington",' +
                '"country": "US"' +
            '}' +
        '}');
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                Name,
                Related_Contact_Phone__c,
                First_Name__c,
                Second_Name__c,
                Package_Name__c,
                Email__c
            FROM Application__c
            WHERE Stripe_Customer_Id__c = 'custome123456123457'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist new Application');
        Application__c newApplication = applications[0];
        System.assertEquals('+1505123456123', newApplication.Related_Contact_Phone__c, 'Wrong phone number on new Application');
        System.assertEquals('FirstName', newApplication.First_Name__c, 'Wrong First Name on new Application');
        System.assertEquals('SecondName', newApplication.Second_Name__c, 'Wrong Second Name on new Application');
        System.assertEquals('Premier', newApplication.Package_Name__c, 'Wrong Package Name on new Application');
        System.assertEquals('test.user@gmail.com', newApplication.Email__c, 'Wrong Email on new Application');
    }

    @IsTest static void addApplicationPersonalDetailData() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        request.requestBody = Blob.valueOf(
            '{ '+
                '"salutation": "Mr",' +
                '"firstName": "John",' +
                '"secondName": "Snow",' +
                '"dateOfBirth": "1964-05-08",' +
                '"workOrPayUKNationalInsurance": true,' +
                '"privateUKPension": false,' +
                '"approxValue": null,' +
                '"insuranceNumber": "AS 12 54 86 A",' +
                '"currentOccupation": "accountant",' +
                '"currentAddressAbroad": {' +
                    '"country": "AU",' +
                    '"street": "123 Test street",' +
                    '"city": "Test",' +
                    '"state": "NSW",' +
                    '"postcode": "1242"' +
                '},' +
                '"lastUKHomeAddress": {' +
                    '"country": "GB",' +
                    '"street": "123 Test street",' +
                    '"city": "London",' +
                    '"state": null,' +
                    '"postcode": "1247"' +
                '},' +
                '"previousUKAddress": [{' +
                    '"country": "GB",' +
                    '"street": "1412 Test",' +
                    '"city": "London",' +
                    '"state": null,' +
                    '"postcode": "4512"' +
                '}],' +
                '"stepName": "Personal Details"' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                First_Name__c,
                Second_Name__c,
                Date_Of_Birth__c,
                Private_UK_Pension__c,
                National_Insurance_Number__c,
                Current_Occupation__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist application');
        Application__c newApplication = applications[0];
        System.assertEquals(false, newApplication.Private_UK_Pension__c, 'Wrong "Private UK Pension" field value on new Application');
        System.assertEquals('John', newApplication.First_Name__c, 'Wrong First Name on new Application');
        System.assertEquals('Snow', newApplication.Second_Name__c, 'Wrong Second Name on new Application');
        // System.assertEquals(Date.valueOf('1964-05-08'), newApplication.Date_Of_Birth__c, 'Wrong Date Of Birth on new Application');
        //System.assertEquals('accountant', newApplication.Current_Occupation__c, 'Wrong Current Occupation on new Application');
    }

    @IsTest static void addApplicationRelationshipDataCase1() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        request.requestBody = Blob.valueOf(
            '{ '+
                '"changeYouName": false,' +
                '"dateOfMarriedOrPartnership": null,' +
                '"divorcedOrwidowed": true,' +
                '"exactDate": "1980-05-07",' +
                '"fullMaindenOrPreviousName": null,' +
                '"single": true,' +
                '"stepName": "Relationship"' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                Did_You_Change_Name__c,
                Are_You_Divorced__c,
                Divorce_Date__c,
                Are_You_Single__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist application');
        Application__c newApplication = applications[0];
        System.assertEquals(false, newApplication.Did_You_Change_Name__c, 'Wrong "Did_You_Change_Name__c" field value on new Application');
        System.assertEquals(true, newApplication.Are_You_Divorced__c, 'Wrong "Are_You_Divorced__c" field value on new Application');
        System.assertEquals(true, newApplication.Are_You_Single__c, 'Wrong "Are_You_Single__c" field value on new Application');
        System.assertEquals(Date.valueOf('1980-05-07'), newApplication.Divorce_Date__c, 'Wrong "Divorce_Date__c" field value on new Application');
    }

    @IsTest static void addApplicationRelationshipDataCase2() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        request.requestBody = Blob.valueOf(
            '{ '+
                '"changeYouName": false,' +
                '"dateOfMarriedOrPartnership": null,' +
                '"divorcedOrwidowed": false,' +
                '"exactDate": "1980-05-07",' +
                '"fullMaindenOrPreviousName": null,' +
                '"single": true,' +
                '"stepName": "Relationship"' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                Did_You_Change_Name__c,
                Are_You_Divorced__c,
                Divorce_Date__c,
                Are_You_Single__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist application');
        Application__c newApplication = applications[0];
        System.assertEquals(false, newApplication.Did_You_Change_Name__c, 'Wrong "Did_You_Change_Name__c" field value on new Application');
        System.assertEquals(false, newApplication.Are_You_Divorced__c, 'Wrong "Are_You_Divorced__c" field value on new Application');
        System.assertEquals(true, newApplication.Are_You_Single__c, 'Wrong "Are_You_Single__c" field value on new Application');
    }

    @IsTest static void addApplicationRelationshipDataCase3() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        request.requestBody = Blob.valueOf(
            '{ '+
                '"changeYouName": false,' +
                '"dateOfMarriedOrPartnership": null,' +
                '"divorcedOrwidowed": false,' +
                '"exactDate": "1980-05-07",' +
                '"fullMaindenOrPreviousName": "Smith",' +
                '"single": false,' +
                '"stepName": "Relationship"' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                Did_You_Change_Name__c,
                Are_You_Divorced__c,
                Divorce_Date__c,
                Are_You_Single__c,
                Full_Maiden_Previous_Name__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist application');
        Application__c newApplication = applications[0];
        System.assertEquals(false, newApplication.Did_You_Change_Name__c, 'Wrong "Did_You_Change_Name__c" field value on new Application');
        System.assertEquals(false, newApplication.Are_You_Divorced__c, 'Wrong "Are_You_Divorced__c" field value on new Application');
        System.assertEquals(false, newApplication.Are_You_Single__c, 'Wrong "Are_You_Single__c" field value on new Application');
        System.assertEquals('Smith', newApplication.Full_Maiden_Previous_Name__c, 'Wrong "Full_Maiden_Previous_Name__c" field value on new Application');
    }

    @IsTest static void addApplicationUKWorkData() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        request.requestBody = Blob.valueOf(
            '{ '+
                '"dateOfLeavingLastUKEmployment": "1999-05-08",' +
                '"endDateOfLastUKEmployer": "1999-04-02",' +
                '"lastUKEmployerAddress": {' +
                    '"country": "GB",' +
                    '"street": "23 Avenue street",' +
                    '"city": "London",' +
                    '"state": null,' +
                    '"postcode": "AS1242"' +
                '},' +
                '"nameOfLastUKEmployer": "London Taxi",' +
                '"startDateOfLastUKEmployer": "1997-05-08",' +
                '"workInUKBeforeLeaving": "Employed",' +
                '"yearsWorkInUK": 10,' +
                '"stepName": "UK Work"' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                Date_Of_Leaving_Last_UK__c,
                Last_UK_Employer_End_Date__c,
                Last_UK_Employer_Name__c,
                Last_UK_Employer_Start_Date__c,
                Type_Of_Employment__c,
                Years_Of_Work_In_The_UK__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist application');
        Application__c newApplication = applications[0];
        System.assertEquals(Date.valueOf('1999-04-02'), newApplication.Date_Of_Leaving_Last_UK__c, 'Wrong "Date_Of_Leaving_Last_UK__c" field value on new Application');
        System.assertEquals(Date.valueOf('1999-04-02'), newApplication.Last_UK_Employer_End_Date__c, 'Wrong "Last_UK_Employer_End_Date__c" field value on new Application');
        System.assertEquals('London Taxi', newApplication.Last_UK_Employer_Name__c, 'Wrong "Last_UK_Employer_Name__c" field value on new Application');
        System.assertEquals(Date.valueOf('1997-05-08'), newApplication.Last_UK_Employer_Start_Date__c, 'Wrong "Last_UK_Employer_Start_Date__c" field value on new Application');
        System.assertEquals('Employed', newApplication.Type_Of_Employment__c, 'Wrong "Type_Of_Employment__c" field value on new Application');
        System.assertEquals(10, newApplication.Years_Of_Work_In_The_UK__c, 'Wrong "Years_Of_Work_In_The_UK__c" field value on new Application');
    }

    @IsTest static void addApplicationWorkAfterUKDataCase3() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        request.requestBody = Blob.valueOf(
            '{ '+
                '"workAfterUK": [{' +
                    '"afterLeftTheUK": "Employed",' +
                    '"country": "US",' +
                    '"street": "Test",' +
                    '"city": "Test",' +
                    '"state": "OH",' +
                    '"postcode": "04085",' +
                    '"endDate": "2008-02-09",' +
                    '"startDate": "2004-03-08",' +
                    '"nameOfYourEmployerAbroad": "Test Employer1"' +
                '},' +
                '{' +
                    '"afterLeftTheUK": "Career Break",' +
                    '"country": "US",' +
                    '"street": "Test",' +
                    '"city": "Test",' +
                    '"state": "OH",' +
                    '"postcode": "04085",' +
                    '"endDate": "2009-02-09",' +
                    '"startDate": "2010-03-08",' +
                    '"nameOfYourEmployerAbroad": "Test Employer2"' +
                '},' +
                '{  "afterLeftTheUK": "Self-Employed",' +
                    '"country": null,' +
                    '"street": null,' +
                    '"city": null,' +
                    '"state": null,' +
                    '"postcode": null,' +
                    '"endDate": "2011-02-09",' +
                    '"startDate": "2012-03-08",' +
                    '"nameOfYourEmployerAbroad": null' +
                '}],' +
                '"stepName": "Work After UK"' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applications = [
            SELECT
                Id
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applications.size(), 'Don\'t exist application');
        Application__c newApplication = applications[0];
        List<Employer__c> relatedEmployers = [
            SELECT
                Employer_Name__c,
                Start_Date__c,
                End_Date__c,
                Type__c
            FROM Employer__c
            WHERE Application__c = :newApplication.Id AND
                  Type__c = 'Work After UK'
        ];
        System.assertEquals(3, relatedEmployers.size(), 'Don\'t create related employers');
    }

    @IsTest static void addDocumentsDetails() {
        Test.setMock(HttpCalloutMock.class, new GeneratePDFMock());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/send-app';
        request.httpMethod = 'POST';
        request.params.put('id', '1111111111111111111');
        List<Application__c> applications = [
            SELECT
                Id,
                Name,
                First_Name__c,
                Second_Name__c,
                Stripe_Transaction_Id__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        Application__c testCurrentApplication = applications[0];
        List<ContentDocumentLink> testLinks = 
            [SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.LatestPublishedVersionId,
                LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocument.Title LIKE '%UPLOAD%' AND
                  LinkedEntityId = :testCurrentApplication.Id
        ];
        request.requestBody = Blob.valueOf(
            '{ '+
                '"applicationId": "' + testCurrentApplication.Id + '",' +
                '"applicationName": "' + testCurrentApplication.Name + '",' +
                '"firstName": "' + testCurrentApplication.First_Name__c + '",' +
                '"lastName": "' + testCurrentApplication.Second_Name__c + '",' +
                '"statements": "' + testLinks[0].ContentDocument.LatestPublishedVersionId + '",' +
                '"stepName": "Documents",' +
                '"youCV": null' +
            '}'
        );
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Application__c> applicationsAfterUpdate = [
            SELECT
                Id,
                Status__c
            FROM Application__c
            WHERE Stripe_Transaction_Id__c = '1111111111111111111'
        ];
        System.assertEquals(1, applicationsAfterUpdate.size(), 'Don\'t exist application');
        Application__c newApplication = applicationsAfterUpdate[0];
        System.assertEquals('Agent Check', newApplication.Status__c, 'Wrong Status__c field value on new Application');
        List<Application_Document__c>  relatedDocuments= [
            SELECT
                Name
            FROM Application_Document__c
            WHERE Application__c = :newApplication.Id
        ];
        System.assertEquals(4, relatedDocuments.size(), 'Didn\'t create all related Application Documents');
    }

    @IsTest static void getPaymentInfoTest() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/payment/getPaymentInfo';
        request.httpMethod = 'POST';
        List<Payment__c> payments = [
            SELECT Id
            FROM Payment__c
            LIMIT 1
        ];
        request.requestBody = Blob.valueOf('{' +
            '"id": "' + payments[0].Id + '"' +
        '}');
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        Map<String, Object> responseData = (Map<String,Object>)JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals(1000000, responseData.get('amount'), 'Incorrect amount in response for payment');
        System.assertEquals('john.snow@gmail.com', responseData.get('email'), 'Incorrect email in response for payment');
        System.assertEquals('Success', responseData.get('status'), 'Incorrect status in response for payment');

    }

    @IsTest static void changeStatusFailedPaymentTest() {
        Test.setMock(HttpCalloutMock.class, new PaymentMethodMock());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/payment/sendPaymentInfo';
        request.httpMethod = 'POST';
        List<Application__c> applications = [
            SELECT
                Id,
                Name,
                First_Name__c,
                Second_Name__c,
                Stripe_Transaction_Id__c,
                Stripe_Customer_Id__c,
                Email__c,
                Payment_Method__c,
                Related_Contact_Phone__c
            FROM Application__c
            LIMIT 1
        ];
        Application__c currentApplication = applications[0];
        List<Payment__c> payments = [
            SELECT Id
            FROM Payment__c
            LIMIT 1
        ];
        request.requestBody = Blob.valueOf('{' +
            '"address": {' +
                '"country": "US",' +
                '"line1": "Test",' +
                '"city": "Test",' +
                '"state": "HI",' +
                '"postal_code": "04075",' +
                '"line2": null' +
            '},' +
            '"amount": 10000,' +
            '"customer": "cus__",' +
            '"email": "' + currentApplication.Email__c + '",' +
            '"id": "' + currentApplication.Id + '",' +
            '"lastName": "' + currentApplication.Second_Name__c + '",' +
            '"name": "' + currentApplication.First_Name__c + ' ' + currentApplication.Second_Name__c + '",' +
            '"paymentId": "' + payments[0].Id + '",' +
            '"paymentMethod": "' + currentApplication.Payment_Method__c + '",' +
            '"phone": "' + currentApplication.Related_Contact_Phone__c + '"' +
        '}');
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.createApplication();
        Test.stopTest();
        List<Payment__c> updatePayment = [
            SELECT
                Status__c,
                Payment_Method__c
            FROM Payment__c
            WHERE Id = :payments[0].Id
        ];
        System.assertEquals('Paid', updatePayment[0].Status__c, 'Didn\'t changed payment\'s status');
        System.assertEquals('pm_123456789', updatePayment[0].Payment_Method__c, 'Incorrect payment method in update Payment');
    }

    @IsTest static void doGetCase1Test() {
        Test.setMock(HttpCalloutMock.class, new GeneratePDFMock());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/get-app';
        request.httpMethod = 'GET';
        List<Application__c> applications = [
            SELECT
                Status__c,
                Stripe_Transaction_Id__c
            FROM Application__c
            LIMIT 1
        ];
        request.params.put('id', applications[0].Stripe_Transaction_Id__c);
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.doGet();
        Test.stopTest();
        Map<String, Object> responseData = (Map<String,Object>)JSON.deserializeUntyped(response.responseBody.toString());
        System.assertNotEquals(0, responseData.size(), 'Didn\'t get application');
        System.assertEquals('Personal Details', responseData.get('currentStep'), 'Incorrect current Step in get Application');
        System.assertNotEquals(null, responseData.get('formData'), 'Incorrect current Step in get Application');
        System.assertEquals('Success', responseData.get('status'), 'Incorrect current Step in get Application');
    }

    @IsTest static void doGetCase2Test() {
        Test.setMock(HttpCalloutMock.class, new GeneratePDFMock());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/get-app';
        request.httpMethod = 'GET';
        List<Application__c> applications = [
            SELECT
                Status__c,
                Stripe_Transaction_Id__c,
                Previous_UK_Address_1__City__s,
                Previous_UK_Address_1__CountryCode__s,
                Previous_UK_Address_1__PostalCode__s,
                Previous_UK_Address_1__StateCode__s,
                Previous_UK_Address_1__Street__s
            FROM Application__c
            LIMIT 1
        ];
        Application__c currentApplication = applications[0];
        currentApplication.Previous_UK_Address_1__City__s        = 'New York';
        currentApplication.Previous_UK_Address_1__CountryCode__s = 'US';
        currentApplication.Previous_UK_Address_1__PostalCode__s  = '50418';
        currentApplication.Previous_UK_Address_1__StateCode__s   = 'AK';
        currentApplication.Previous_UK_Address_1__Street__s      = 'Test';
        update currentApplication;
        request.params.put('id', currentApplication.Stripe_Transaction_Id__c);
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.doGet();
        Test.stopTest();
        Map<String, Object> responseData = (Map<String,Object>)JSON.deserializeUntyped(response.responseBody.toString());
        System.assertNotEquals(0, responseData.size(), 'Didn\'t get application');
        System.assertEquals('Personal Details', responseData.get('currentStep'), 'Incorrect current Step in get Application');
        System.assertNotEquals(null, responseData.get('formData'), 'Incorrect current Step in get Application');
        System.assertEquals('Success', responseData.get('status'), 'Incorrect current Step in get Application');

    }

    @IsTest static void doGetCase3Test() {
        Test.setMock(HttpCalloutMock.class, new GeneratePDFMock());
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/api/v1/form/get-app';
        request.httpMethod = 'GET';
        List<Application__c> applications = [
            SELECT
                Id,
                Status__c,
                Stripe_Transaction_Id__c
            FROM Application__c
            LIMIT 1
        ];
        Application__c currentApplication = applications[0];
        TestDataFactory.createEmployer(
            currentApplication.Id,
            'Work After UK',
            'Employed',
            true
        );
        request.params.put('id', currentApplication.Stripe_Transaction_Id__c);
        RestContext.request = request;
        RestContext.response= response;
        Test.startTest();
        ApplicationManager.doGet();
        Test.stopTest();
        Map<String, Object> responseData = (Map<String,Object>)JSON.deserializeUntyped(response.responseBody.toString());
        System.assertNotEquals(0, responseData.size(), 'Didn\'t get application');
        System.assertEquals('Personal Details', responseData.get('currentStep'), 'Incorrect current Step in get Application');
        System.assertNotEquals(null, responseData.get('formData'), 'Incorrect current Step in get Application');
        System.assertEquals('Success', responseData.get('status'), 'Incorrect current Step in get Application');

    }

    private class PaymentMethodMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                    '"id":"pm124512451", ' +
                    '"card":{' +
                        '"brand":"visa", ' +
                        '"last4":"4242"' +
                    '}' +
                '}');
            res.setStatusCode(200);
            return res;
        }
    }
}
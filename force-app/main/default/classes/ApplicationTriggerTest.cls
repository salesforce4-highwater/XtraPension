@isTest
public with sharing class ApplicationTriggerTest {
    @IsTest
    static void createApplicationTriggerTest(){
        Application__c testApp = new Application__c(
            First_Name__c            = 'John',
            Second_Name__c           = 'Snow',
            Related_Contact_Phone__c = '+123451245',
            Email__c                 = 'john.snow@test.com',
            Package_Name__c          = 'Freebie'
        );
        insert testApp;
        List<Application__c> testApps = [
            SELECT
                First_Name__c,
                Second_Name__c,
                Package_Name__c,
                Contact__c,
                Last_UK_Home_Address__CountryCode__s
            FROM Application__c
        ];
        System.assertNotEquals(0, testApps.size(), 'Freebie Application didn\'t create');
        Application__c app = testApps[0];
        System.assertEquals('John', app.First_Name__c, 'Application First Name must be John');
        System.assertNotEquals(null, app.Contact__c, 'Related contact must be not null');
        System.assertEquals('GB', app.Last_UK_Home_Address__CountryCode__s, 'CountryCode must be GB');
    }

    @IsTest
    static void updateApplicationDocumentStatusTest() {
        Application__c testApp = new Application__c(
            First_Name__c            = 'John',
            Second_Name__c           = 'Snow',
            Related_Contact_Phone__c = '+123451245',
            Email__c                 = 'john.snow@test.com',
            Package_Name__c          = 'Freebie'
        );
        insert testApp;
        TestDataFactory.createApplicationDocument(testApp.Id, true);
        TestDataFactory.createCF083ApplicationDocument(testApp.Id, true);
        TestDataFactory.createAgentApplicationDocument(testApp.Id, true);

        List<Application__c> testApps = [
            SELECT
                Status__c
            FROM Application__c
        ];
        testApps[0].Status__c = 'Printing House';
        update testApps;

        List<Application_Document__c> testAppDocs = [
            SELECT
                Status__c
            FROM Application_Document__c
            WHERE Application__c = :testApps[0].Id
        ];
        for (Application_Document__c doc : testAppDocs) {
            System.assertEquals('Ready For PH', doc.Status__c);
        }
    }

    @IsTest
    static void updateSelfemployedAbroadFieldTestCase1() {
        Application__c testApp = new Application__c(
            First_Name__c                       = 'John',
            Second_Name__c                      = 'Snow',
            Related_Contact_Phone__c            = '+123451245',
            Email__c                            = 'john.snow@test.com',
            Package_Name__c                     = 'Freebie',
            SelfEmployment_Employment_Abroad__c = 'Employed'
        );
        insert testApp;
        Employer__c selfEmployedEmployer = TestDataFactory.createEmployer(testApp.Id, 'Work After UK', 'Self-Employed', true);
        Employer__c employedEmployer     = TestDataFactory.createEmployer(testApp.Id, 'Work After UK', 'Employed', false);
        employedEmployer.Employers_Address__City__s        = 'Test';
        employedEmployer.Employers_Address__CountryCode__s = 'AU';
        employedEmployer.Employers_Address__PostalCode__s  = '1124';
        employedEmployer.Employers_Address__StateCode__s   = 'QLD';
        employedEmployer.Employers_Address__Street__s      = '12 Test Street';
        employedEmployer.Employers_Address_State__c        = 'Queensland';
        employedEmployer.Employers_Address_Country__c      = 'Australia';
        insert employedEmployer;
        testApp.SelfEmployment_Employment_Abroad__c = 'Both';
        update testApp;
        List<Application__c> applications = [
            SELECT
                Abroad_Employer_Address1__City__s,
                Abroad_Employer_Address1__CountryCode__s,
                Abroad_Employer_Address1__PostalCode__s,
                Abroad_Employer_Address1__StateCode__s,
                Abroad_Employer_Address1__Street__s,
                Abroad_Employer_End_Date1__c,
                Abroad_Employer_Name1__c,
                Abroad_Employer_Start_Date1__c,
                Abroad_Employer_Address1_State__c,
                Abroad_Employer_Address1_Country__c,
                Self_Employed_Start_Date1__c,
                Self_Employed_End_Date1__c,
                SelfEmployment_Employment_Abroad__c
            FROM Application__c
            LIMIT 1
        ];
        if (applications.isEmpty()) {
            return;
        }
        Application__c applicationAfterUpdate = applications[0];
        System.assertEquals(employedEmployer.Employers_Address__City__s, applicationAfterUpdate.Abroad_Employer_Address1__City__s);
        System.assertEquals(employedEmployer.Employers_Address__CountryCode__s, applicationAfterUpdate.Abroad_Employer_Address1__CountryCode__s);
    }

    @IsTest
    static void updateSelfemployedAbroadFieldTestCase2() {
        Application__c testApp = new Application__c(
            First_Name__c                       = 'John',
            Second_Name__c                      = 'Snow',
            Related_Contact_Phone__c            = '+123451245',
            Email__c                            = 'john.snow@test.com',
            Package_Name__c                     = 'Freebie',
            SelfEmployment_Employment_Abroad__c = 'Self-employed'
        );
        insert testApp;
        Employer__c selfEmployedEmployer = TestDataFactory.createEmployer(testApp.Id, 'Work After UK', 'Self-Employed', true);
        Employer__c employedEmployer     = TestDataFactory.createEmployer(testApp.Id, 'Work After UK', 'Employed', false);
        employedEmployer.Employers_Address__City__s        = 'Test';
        employedEmployer.Employers_Address__CountryCode__s = 'AU';
        employedEmployer.Employers_Address__PostalCode__s  = '1124';
        employedEmployer.Employers_Address__StateCode__s   = 'QLD';
        employedEmployer.Employers_Address__Street__s      = '12 Test Street';
        employedEmployer.Employers_Address_State__c        = 'Queensland';
        employedEmployer.Employers_Address_Country__c      = 'Australia';
        insert employedEmployer;
        testApp.SelfEmployment_Employment_Abroad__c = 'Employed';
        update testApp;
        List<Application__c> applications = [
            SELECT
                Abroad_Employer_Address1__City__s,
                Abroad_Employer_Address1__CountryCode__s,
                Abroad_Employer_Address1__PostalCode__s,
                Abroad_Employer_Address1__StateCode__s,
                Abroad_Employer_Address1__Street__s,
                Abroad_Employer_End_Date1__c,
                Abroad_Employer_Name1__c,
                Abroad_Employer_Start_Date1__c,
                Abroad_Employer_Address1_State__c,
                Abroad_Employer_Address1_Country__c,
                Self_Employed_Start_Date1__c,
                Self_Employed_End_Date1__c,
                SelfEmployment_Employment_Abroad__c
            FROM Application__c
            LIMIT 1
        ];
        if (applications.isEmpty()) {
            return;
        }
        Application__c applicationAfterUpdate = applications[0];
        System.assertEquals(employedEmployer.Employers_Address__City__s, applicationAfterUpdate.Abroad_Employer_Address1__City__s);
        System.assertEquals(employedEmployer.Employers_Address__CountryCode__s, applicationAfterUpdate.Abroad_Employer_Address1__CountryCode__s);
        System.assertEquals(null, applicationAfterUpdate.Self_Employed_Start_Date1__c);
    }

    @IsTest
    static void updateRelatedDocumentsAfterChangeApplicationNameTest() {
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
        Application_Document__c testCustomLetter = TestDataFactory.createApplicationDocument(testApplication.Id, true);
        Application_Document__c testCF083 = TestDataFactory.createCF083ApplicationDocument(testApplication.Id, true);
        System.assertEquals(true, testCustomLetter.File_Name__c.contains('John_Snow'));
        System.assertEquals(true, testCF083.File_Name__c.contains('John_Snow'));
        Test.startTest();
        testApplication.First_Name__c = 'Jimmy';
        update testApplication;
        Test.stopTest();
        List<Application_Document__c> applicationDocumentsAfterUpdate = [
            SELECT File_Name__c
            FROM Application_Document__c
            WHERE Application__c = :testApplication.Id
        ];
        for (Application_Document__c document : applicationDocumentsAfterUpdate) {
            System.assertEquals(false, document.File_Name__c.contains('John_Snow'));
            System.assertEquals(true, document.File_Name__c.contains('Jimmy_Snow'));
        }
    }

    @IsTest
    static void updateRelatedContactAfterChangeEmail() {
        TestDataFactory.createProductsWithPrices();
        TestDataFactory.createTestCountry(true);
        Account account = TestDataFactory.createAccount(true);
        List<Contact> currentContact = [
            SELECT
                Id,
                AccountId,
                Email
            FROM Contact
            WHERE AccountId = :account.Id
            LIMIT 1
        ];
        Id personContactId = currentContact[0].Id;
        Application__c testApplication = TestDataFactory.createApplication(personContactId, true);
        Test.startTest();
        testApplication.Email__c = 'jimmy.snow@gmail.com';
        update testApplication;
        Test.stopTest();
        List<Contact> currentContactAfterUpdate = [
            SELECT
                Email
            FROM Contact
            WHERE AccountId = :account.Id
            LIMIT 1
        ];
        System.assertNotEquals(currentContact[0].Email, currentContactAfterUpdate[0].Email);
        System.assertEquals('jimmy.snow@gmail.com', currentContactAfterUpdate[0].Email);
    }
}
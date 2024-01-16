@RestResource(UrlMapping='/api/v1/*')
global with sharing class ApplicationManager {

    @HttpPost
    global static void createApplication() {
        RestRequest request = RestContext.request;
        String reqURI = request.requestURI;
        RestResponse response = RestContext.response;
        String requestBody = request.requestBody.toString();
        Map<String, Object> result = new Map<String, Object>();
        if (reqURI == '/api/v1/form/create-app') {
            RequestDataWrapper requestData = (RequestDataWrapper) JSON.deserialize(requestBody, RequestDataWrapper.class);
            response.responseBody = Blob.valueOf(JSON.serialize(ApplicationManagerHandler.createApplication(requestData)));
        } else if(reqURI == '/api/v1/form/send-app') {
            String stepName = (String)((Map<String, Object>) JSON.deserializeUntyped(requestBody)).get('stepName');
            String stripeId = request.params.get('id');
            if (String.isNotBlank(stripeId) && stepName == 'Personal Details') {
                ApplicationPersonalStepWrapper requestData = (ApplicationPersonalStepWrapper) JSON.deserialize(requestBody.replace('""', 'null'), ApplicationPersonalStepWrapper.class);
                result = ApplicationManagerHandler.setApplicationPersonalDetails(requestData, stripeId);
            } else if (String.isNotBlank(stripeId) && stepName == 'Relationship') {
                RelationshipStepWrapper requestDataRelationship = (RelationshipStepWrapper) JSON.deserialize(requestBody.replace('""', 'null'), RelationshipStepWrapper.class);
                result = ApplicationManagerHandler.setApplicationRelationshipDetails(requestDataRelationship, stripeId);
            } else if (String.isNotBlank(stripeId) && stepName == 'UK Work') {
                UkWorkStepWrapper requestDataUKWork = (UkWorkStepWrapper) JSON.deserialize(requestBody.replace('""', 'null'), UkWorkStepWrapper.class);
                result = ApplicationManagerHandler.setApplicationUkWorkDetails(requestDataUKWork, stripeId);
            } else if (String.isNotBlank(stripeId) && stepName == 'Work After UK') {
                WorkAfterUKStepWrapper requestDataWorkAfterUK = (WorkAfterUKStepWrapper) JSON.deserialize(requestBody.replace('""', 'null'), WorkAfterUKStepWrapper.class);
                result = ApplicationManagerHandler.setApplicationWorkAfterUKDetails(requestDataWorkAfterUK, stripeId);
            } else if(String.isNotBlank(stripeId) && stepName == 'Documents') {
                DocumentsStepWrapper requestDataDocuments = (DocumentsStepWrapper) JSON.deserialize(requestBody.replace('""', 'null'), DocumentsStepWrapper.class);
                result = ApplicationManagerHandler.setApplicationDocumentsDetails(requestDataDocuments, stripeId);
                result.put('status', 'Success');
            } else {
                result.put('error', 'Id Not Found');
            }
            response.responseBody = Blob.valueOf(JSON.serialize(result));
        } else if(reqURI == '/api/v1/payment/getPaymentInfo') {
            String paymentId = (String)((Map<String, Object>)JSON.deserializeUntyped(requestBody)).get('id');
            result = ApplicationManagerHandler.getPaymentData(paymentId);
            response.responseBody = Blob.valueOf(JSON.serialize(result));
        } else if(reqURI == '/api/v1/payment/sendPaymentInfo') {
            PaymentDataWrapper paymentData = (PaymentDataWrapper) JSON.deserialize(requestBody.replace('""', 'null'), PaymentDataWrapper.class);
            result = ApplicationManagerHandler.changeStatusFailedPayment(paymentData);
            response.responseBody = Blob.valueOf(JSON.serialize(result));
        }
    }

    //api/v1/form/get-app get Id (stripeId => application)

    @HttpGet
    global static void doGet() {
        RestResponse response = RestContext.response;
        String reqURI = RestContext.request.requestURI;

        if (reqURI == '/api/v1/form/get-app') {

            String stripeId = RestContext.request.params.get('id');

            Map<String, Object> result = new Map<String, Object>();

            if (String.isNotBlank(stripeId)) {
                result = ApplicationManagerHandler.getApplication(stripeId, result);
                Application__c app = (Application__c) result.get('formData');
                if (app != null) {
                    FormDataWrapper formData = new FormDataWrapper();
                    ApplicationPersonalStepWrapper personalData = new ApplicationPersonalStepWrapper();
                    personalData.salutation                    = app.Salutation__c;
                    personalData.firstName                     = app.First_Name__c;
                    personalData.secondName                    = app.Second_Name__c;
                    personalData.dateOfBirth                   = String.valueOf(app.Date_Of_Birth__c);
                    personalData.insuranceNumber               = app.National_Insurance_Number__c;
                    personalData.workOrPayUKNationalInsurance  = app.Work_Or_Pay_UK_National_Insurance__c;
                    personalData.privateUKPension              = app.Private_UK_Pension__c;
                    personalData.approxValue                   = app.Approx_Value_Of_UK_Pension__c;
                    personalData.currentOccupation             = app.Current_Occupation__c;
                    personalData.isKnowNationalInsuranceNumber = app.Is_Know_National_Insurance_Number__c;

                    currentAddressAbroad currentAddressAbroadData = new currentAddressAbroad();
                    if (app.Current_Address_Abroad__Street__s == null) {
                        currentAddressAbroadData.country = 'IE';
                    } else currentAddressAbroadData.country = app.Current_Address_Abroad__CountryCode__s;
                    currentAddressAbroadData.street         = app.Current_Address_Abroad__Street__s ;
                    currentAddressAbroadData.city           = app.Current_Address_Abroad__City__s;
                    currentAddressAbroadData.state          = app.Current_Address_Abroad__StateCode__s;
                    currentAddressAbroadData.postcode       = app.Current_Address_Abroad__PostalCode__s;

                    personalData.currentAddressAbroad = currentAddressAbroadData;

                    lastUKHomeAddress lastUKHomeAddressData = new lastUKHomeAddress();
                    lastUKHomeAddressData.country  = 'GB';
                    lastUKHomeAddressData.street   = app.Previous_UK_Address_1__Street__s;
                    lastUKHomeAddressData.city     = app.Previous_UK_Address_1__City__s;
                    lastUKHomeAddressData.state    = app.Previous_UK_Address_1__StateCode__s;
                    lastUKHomeAddressData.postcode = app.Previous_UK_Address_1__PostalCode__s;
                    lastUKHomeAddressData.fromDate = app.Previous_UK_Address_Start_Date_1__c;
                    lastUKHomeAddressData.toDate   = app.Previous_UK_Address_End_Date_1__c;

                    personalData.lastUKHomeAddress = lastUKHomeAddressData;

                    lastUKHomeAddress lastUKHomeAddressData2 = new lastUKHomeAddress();
                    lastUKHomeAddressData2.country  = 'GB';
                    lastUKHomeAddressData2.street   = app.Previous_UK_Address_2__Street__s;
                    lastUKHomeAddressData2.city     = app.Previous_UK_Address_2__City__s;
                    lastUKHomeAddressData2.state    = app.Previous_UK_Address_2__StateCode__s;
                    lastUKHomeAddressData2.postcode = app.Previous_UK_Address_2__PostalCode__s;
                    lastUKHomeAddressData2.fromDate = app.Previous_UK_Address_Start_Date_2__c;
                    lastUKHomeAddressData2.toDate   = app.Previous_UK_Address_End_Date_2__c;

                    personalData.lastUKHomeAddress2 = lastUKHomeAddressData2;

                    lastUKHomeAddress lastUKHomeAddressData3 = new lastUKHomeAddress();
                    lastUKHomeAddressData3.country  = 'GB';
                    lastUKHomeAddressData3.street   = app.Previous_UK_Address_3__Street__s;
                    lastUKHomeAddressData3.city     = app.Previous_UK_Address_3__City__s;
                    lastUKHomeAddressData3.state    = app.Previous_UK_Address_3__StateCode__s;
                    lastUKHomeAddressData3.postcode = app.Previous_UK_Address_3__PostalCode__s;
                    lastUKHomeAddressData3.fromDate = app.Previous_UK_Address_Start_Date_3__c;
                    lastUKHomeAddressData3.toDate   = app.Previous_UK_Address_End_Date_3__c;

                    personalData.lastUKHomeAddress3 = lastUKHomeAddressData3;

                    // List<previousUKAddress> previousUKAddressData = new List<previousUKAddress>();
                    // for (Integer i = 1; i <= 5; i++) {
                    //     if (app.get('Previous_UK_Address_' + i + '__Street__s') != null) {
                    //         previousUKAddress currentPreviousUKAddress = new previousUKAddress();
                    //         currentPreviousUKAddress.country  = (String) app.get('Previous_UK_Address_' + i + '__CountryCode__s');
                    //         currentPreviousUKAddress.street   = (String) app.get('Previous_UK_Address_' + i + '__Street__s');
                    //         currentPreviousUKAddress.city     = (String) app.get('Previous_UK_Address_' + i + '__City__s');
                    //         currentPreviousUKAddress.state    = (String) app.get('Previous_UK_Address_' + i + '__StateCode__s');
                    //         currentPreviousUKAddress.postcode = (String) app.get('Previous_UK_Address_' + i + '__PostalCode__s');
                    //         previousUKAddressData.add(currentPreviousUKAddress);
                    //     }
                    // }
                    // personalData.previousUKAddress = previousUKAddressData;
                    formData.personal = personalData;

                    RelationshipStepWrapper relationData    = new RelationshipStepWrapper();
                    relationData.changeYouName              = app.Did_You_Change_Name__c;
                    relationData.dateOfMarriedOrPartnership = app.Date_Of_Marriage_Or_Civil_Partnership__c;
                    relationData.divorcedOrwidowed          = app.Are_You_Divorced__c;
                    relationData.fullMaindenOrPreviousName  = app.Full_Maiden_Previous_Name__c;
                    relationData.single                     = app.Are_You_Single__c;
                    relationData.exactDate                  = app.Divorce_Date__c;

                    formData.relationship = relationData;

                    Employer__c ukEmployer = new Employer__c();
                    for (Employer__c employer : app.Employers__r) {
                        if (employer.Type__c == 'UK Work') {
                            ukEmployer = employer;
                            break;
                        }
                    }
                    UkWorkStepWrapper ukWorkData = new UkWorkStepWrapper();
                    ukWorkData.dateOfLeavingLastUKEmployment = app.Date_Of_Leaving_Last_UK__c;
                    ukWorkData.workInUKBeforeLeaving         = app.Type_Of_Employment__c;
                    ukWorkData.yearsWorkInUK                 = app.Years_Of_Work_In_The_UK__c;
                    ukWorkData.endDateOfLastUKEmployer   = app.Last_UK_Employer_End_Date__c;
                    ukWorkData.nameOfLastUKEmployer      = app.Last_UK_Employer_Name__c;
                    ukWorkData.startDateOfLastUKEmployer = app.Last_UK_Employer_Start_Date__c;

                    LastUKEmployerAddress lastUKEmployerAddressData = new LastUKEmployerAddress();
                    lastUKEmployerAddressData.city     = app.Last_UK_Employer_Address__City__s;
                    lastUKEmployerAddressData.country  = 'GB';
                    lastUKEmployerAddressData.postcode = app.Last_UK_Employer_Address__PostalCode__s;
                    lastUKEmployerAddressData.street   = app.Last_UK_Employer_Address__Street__s;
                    lastUKEmployerAddressData.state    = app.Last_UK_Employer_Address__StateCode__s;
                    ukWorkData.lastUKEmployerAddress   = lastUKEmployerAddressData;

                    formData.ukwork = ukWorkData;

                    List<AfterUKEmployerWrapper> workAfterUKData = new List<AfterUKEmployerWrapper>();

                    for (Employer__c employer : app.Employers__r) {
                        if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Career Break') {
                            AfterUKEmployerWrapper currentCareerBreakWrapper       = new AfterUKEmployerWrapper();
                            currentCareerBreakWrapper.startDate                = employer.Start_Date__c;
                            currentCareerBreakWrapper.endDate                  = employer.End_Date__c;
                            currentCareerBreakWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(currentCareerBreakWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Employed') {
                            AfterUKEmployerWrapper currentEmployedWrapper = new AfterUKEmployerWrapper();
                            currentEmployedWrapper.nameOfYourEmployerAbroad = employer.Employer_Name__c;
                            currentEmployedWrapper.country                  = employer.Employers_Address__CountryCode__s;
                            currentEmployedWrapper.street                   = employer.Employers_Address__Street__s;
                            currentEmployedWrapper.city                     = employer.Employers_Address__City__s;
                            currentEmployedWrapper.state                    = employer.Employers_Address__StateCode__s;
                            currentEmployedWrapper.postcode                 = employer.Employers_Address__PostalCode__s;
                            currentEmployedWrapper.startDate                = employer.Start_Date__c;
                            currentEmployedWrapper.endDate                  = employer.End_Date__c;
                            currentEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(currentEmployedWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Self-Employed') {
                            AfterUKEmployerWrapper selfEmployedWrapper = new AfterUKEmployerWrapper();
                            selfEmployedWrapper.startDate                = employer.Start_Date__c;
                            selfEmployedWrapper.endDate                  = employer.End_Date__c;
                            selfEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(selfEmployedWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Unemployed') {
                            AfterUKEmployerWrapper unemployedEmployedWrapper = new AfterUKEmployerWrapper();
                            unemployedEmployedWrapper.startDate                = employer.Start_Date__c;
                            unemployedEmployedWrapper.endDate                  = employer.End_Date__c;
                            unemployedEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(unemployedEmployedWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Family Carer') {
                            AfterUKEmployerWrapper familyCarerEmployedWrapper = new AfterUKEmployerWrapper();
                            familyCarerEmployedWrapper.startDate                = employer.Start_Date__c;
                            familyCarerEmployedWrapper.endDate                  = employer.End_Date__c;
                            familyCarerEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(familyCarerEmployedWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Homemaker') {
                            AfterUKEmployerWrapper homemakerEmployedWrapper = new AfterUKEmployerWrapper();
                            homemakerEmployedWrapper.startDate                = employer.Start_Date__c;
                            homemakerEmployedWrapper.endDate                  = employer.End_Date__c;
                            homemakerEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(homemakerEmployedWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Disabled') {
                            AfterUKEmployerWrapper disabledEmployedWrapper = new AfterUKEmployerWrapper();
                            disabledEmployedWrapper.startDate                = employer.Start_Date__c;
                            disabledEmployedWrapper.endDate                  = employer.End_Date__c;
                            disabledEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(disabledEmployedWrapper);
                        } else if (employer.Type__c == 'Work After UK' && employer.Type_Of_After_UK_Employment__c == 'Retired') {
                            AfterUKEmployerWrapper retiredEmployedWrapper = new AfterUKEmployerWrapper();
                            retiredEmployedWrapper.startDate                = employer.Start_Date__c;
                            retiredEmployedWrapper.endDate                  = employer.End_Date__c;
                            retiredEmployedWrapper.afterLeftTheUK           = employer.Type_Of_After_UK_Employment__c;
                            workAfterUKData.add(retiredEmployedWrapper);
                        }
                    }

                    formData.workAfterUK = workAfterUKData;

                    DocumentsStepWrapper documentsData = new DocumentsStepWrapper();
                    documentsData.applicationId = app.Id;
                    documentsData.applicationName = app.Name;
                    formData.documents = documentsData;
                    result.put('formData', formData);
                }
            } else {
                result.put('error', 'Id Not Found');
            }
            response.responseBody = Blob.valueOf(JSON.serialize(result));
        }
    }
    public class FormDataWrapper {
        public ApplicationPersonalStepWrapper personal;
        public RelationshipStepWrapper relationship;
        public UkWorkStepWrapper ukwork;
        public List<AfterUKEmployerWrapper> workAfterUK;
        public DocumentsStepWrapper documents;
    }

    public class RequestDataWrapper {
        public String id;
        public Decimal amount;
        public String email;
        public String phone;
        public String name;
        public AddressDataWrapper address;
        public String firstName;
        public String lastName;
        public String packageName;
        public String paymentMethod;
        public String customer;
        public Boolean tax;
    }

    public class AddressDataWrapper {
        //line1 == street
        //line2 - optional
        public String line1;
        public String line2;
        public String postal_code;
        public String state;
        public String city;
        public String country;
    }

    public class ApplicationPersonalStepWrapper {
        public String salutation;
        public String firstName;
        public String secondName;
        public String dateOfBirth;
        public String insuranceNumber;
        public Boolean workOrPayUKNationalInsurance;
        public Boolean privateUKPension;
        public Decimal approxValue;
        public String currentOccupation;
        public currentAddressAbroad currentAddressAbroad;
        public lastUKHomeAddress lastUKHomeAddress;
        public lastUKHomeAddress lastUKHomeAddress2;
        public lastUKHomeAddress lastUKHomeAddress3;
        public List<previousUKAddress> previousUKAddress;
        public String stepName;
        public Boolean isKnowNationalInsuranceNumber;
    }

    public class currentAddressAbroad {
        public String country;
        public String street;
        public String city;
        public String state;
        public String postcode;
    }

    public class lastUKHomeAddress {
        public String country;
        public String street;
        public String city;
        public String state;
        public String postcode;
        public Date fromDate;
        public Date toDate;
    }

    public class previousUKAddress {
        public String country;
        public String street;
        public String city;
        public String state;
        public String postcode;
    }

    public class RelationshipStepWrapper {
        public Boolean changeYouName;
        public Date dateOfMarriedOrPartnership;
        public Boolean divorcedOrwidowed;
        public String fullMaindenOrPreviousName;
        public Boolean single;
        public Date exactDate;
        public String stepName;
    }

    public class UkWorkStepWrapper {
        public Date dateOfLeavingLastUKEmployment;
        public Date endDateOfLastUKEmployer;
        public String nameOfLastUKEmployer;
        public Date startDateOfLastUKEmployer;
        public String workInUKBeforeLeaving;
        public Decimal yearsWorkInUK;
        public LastUKEmployerAddress lastUKEmployerAddress;
        public String stepName;
    }

    public class LastUKEmployerAddress {
        public String country;
        public String street;
        public String city;
        public String state;
        public String postcode;
    }

    public class WorkAfterUKStepWrapper {
        public List<AfterUKEmployerWrapper> workAfterUK;
        public String stepName;
    }

    public class AfterUKEmployerWrapper {
        public String nameOfYourEmployerAbroad;
        public String afterLeftTheUK;
        public String country;
        public String street;
        public String city;
        public String state;
        public String postcode;
        public Date startDate;
        public Date endDate;
    }

    public class DocumentsStepWrapper {
        public String applicationId;
        public String applicationName;
        public String statements;
        public String youCV;
    }

    public class PaymentDataWrapper {
        public String id;
        public String paymentId;
        public String paymentMethod;
        public String customer;
        public Decimal amount;
        public String email;
        public String name;
        public String firstName;
        public String lastName;
        public String phone;
        public AddressDataWrapper address;
    }
}
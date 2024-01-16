import { api, track, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import chargeGuidanceProduct from '@salesforce/apex/ChargeGuidanceProductController.chargeProduct';
import getApplication from '@salesforce/apex/ChargeGuidanceProductController.getApplication';


export default class ChargeGuidanceProduct extends LightningModal  {
    @api recordId;
    @api content;
    @track showSpinner = false;
    @track result;
    @track error;
    @api applicationData;
    @api chargeProductName;
    @api chargeAmount;
    @api errorData;

    @wire(getApplication, {recordId: '$recordId'})
    retrievedApplication({error, data}) {
        if(data) {
            this.applicationData = data;
            this.checkApplicationStatus();
        } else if(error) {
            console.log('error: ', error);
        }
    }
    checkApplicationStatus() {
        let appStatus =  this.applicationData.application.Status__c;
        let packageName = this.applicationData.application.Package_Name__c;
        console.log(this.applicationData.payments);
        if (appStatus == 'Check & Charge') {
            this.chargeProductName = 'Guidance on HMRC Reply';
            this.chargeAmount = this.applicationData.application.Live_In_The_EU__c ? '€300' : '€244';
        } else if (appStatus == 'Tax Call (Prem)') {
            this.chargeProductName = 'Pension & Tax Advice';
            this.chargeAmount =  this.applicationData.application.Live_In_The_EU__c ? '€500' : '€407';
        } else {
            this.errorData = 'You are not on stage \'Check & Charge\' or \'Tax Call (Prem)\'';
            return;
        }
        if ((appStatus == 'Check & Charge' || appStatus == 'Tax Call (Prem)') && packageName == 'Basic') {
            this.chargeProductName = null;
            this.errorData = 'You can\'t charge when XP Service is Basic!';
            return;
        }
        if (appStatus == 'Check & Charge') {
            var paymentStatus = this.applicationData.payments.find(payment => payment.Product__r.Name == 'Guidance on HMRC Reply').Status__c;
            if (paymentStatus == 'Paid') {
                this.chargeProductName = null;
                this.errorData = 'You have already paid \'Guidance on HMRC Reply\' product!';
                return;
            }
        }
        if (appStatus == 'Tax Call (Prem)') {
            var paymentStatus = this.applicationData.payments.find(payment => payment.Product__r.Name == 'Pension & Tax Advice').Status__c;
            if (paymentStatus == 'Paid') {
                this.chargeProductName = null;
                this.errorData = 'You have already paid \'Pension & Tax Advice\' product!';
                return;
            }
        }
    }

    handleCharge() {
        this.showSpinner = !this.showSpinner;
        chargeGuidanceProduct({
            recordId : this.recordId
        })
        .then(result => {
            this.result = result;
                this.showSpinner = !this.showSpinner;
            const evt = new ShowToastEvent({
                title: result.title,
                message: result.message,
                variant: result.variant
            });
            this.dispatchEvent(evt);
            this.closeModal();
        }).catch(error => {
            this.error = error;
                this.showSpinner = !this.showSpinner;
            const evt = new ShowToastEvent({
                title: 'Error',
                message: 'You didn\'t charge Guidance Product. Error is ' + this.error,
                variant: 'error',
            });
            this.dispatchEvent(evt);
            this.closeModal();
        });
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    @api get isExistChargeProductName() {
        return this.chargeProductName != null ? true : false;
    }
    @api get isExistErrorData() {
        return this.errorData != null ? true : false;
    }
}
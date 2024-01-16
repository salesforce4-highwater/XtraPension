import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";

import ESTIMATE_FIELD from "@salesforce/schema/Lead.Estimate__c";

const fields = [ESTIMATE_FIELD];

export default class LeadEditForm extends LightningElement {
    @api recordId;
    @api objectApiName;
    isShowEditForm = false;

    @wire(getRecord, { recordId: "$recordId", fields })
    lead;

    handleSuccess() {
        this.showMessage('Success!', 'Lead edited successfully.', 'success');
        this.handleOpenModal();
    }

    showMessage(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    handleOpenModal() {
        this.isShowEditForm = !this.isShowEditForm;
    }

    handleClose() {
        this.handleOpenModal();
    }

    get estimate() {
        return getFieldValue(this.lead.data, ESTIMATE_FIELD);
    }
}
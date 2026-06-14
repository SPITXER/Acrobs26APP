/**
 * Acropolis — Firebase Cloud Function: send friend-added emails
 *
 * Setup (one time):
 *   1. cd functions && npm install
 *   2. firebase functions:secrets:set SENDGRID_API_KEY
 *      (paste your SendGrid API key when prompted)
 *   3. firebase deploy --only functions
 *
 * The function triggers whenever a new job lands in /mail_queue/{id}
 * in the Realtime Database, sends the email via SendGrid, then
 * deletes the job node so it doesn't fire again.
 *
 * SendGrid free tier: 100 emails/day — plenty for early-stage use.
 * Create a free account at https://sendgrid.com and verify a sender email.
 */

const { onValueCreated } = require('firebase-functions/v2/database');
const { defineSecret }   = require('firebase-functions/params');
const admin              = require('firebase-admin');
const sgMail             = require('@sendgrid/mail');

admin.initializeApp();

const SENDGRID_API_KEY = defineSecret('SENDGRID_API_KEY');

// CHANGE THIS to a verified sender address in your SendGrid account
const FROM_EMAIL = 'assembly@acropolis.app';
const FROM_NAME  = 'Acropolis Assembly';

exports.sendFriendEmail = onValueCreated(
  {
    ref:     '/mail_queue/{jobId}',
    region:  'us-central1',
    secrets: [SENDGRID_API_KEY],
  },
  async (event) => {
    const job   = event.data.val();
    const jobId = event.params.jobId;

    if (!job || job.processed) return null;

    const { to, subject, html } = job;
    if (!to || !subject || !html) {
      console.warn(`mail_queue/${jobId}: missing fields, skipping`);
      await event.data.ref.remove();
      return null;
    }

    sgMail.setApiKey(SENDGRID_API_KEY.value());

    try {
      await sgMail.send({ to, from: { email: FROM_EMAIL, name: FROM_NAME }, subject, html });
      console.log(`Email sent to ${to} (job ${jobId})`);
    } catch (err) {
      console.error(`Failed to send email to ${to}:`, err.response?.body ?? err.message);
    }

    // Remove the job so it doesn't retrigger
    await event.data.ref.remove();
    return null;
  }
);

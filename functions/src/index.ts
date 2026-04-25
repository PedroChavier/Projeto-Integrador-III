import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const app = admin.initializeApp();  
const db = app.firestore();

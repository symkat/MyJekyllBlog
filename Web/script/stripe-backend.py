#! /usr/bin/env python3.6

"""
server.py
Stripe Sample.
Python 3.6 or newer required.
"""
import os
from flask import Flask, redirect, jsonify, json, request, current_app
import yaml

import stripe

with open('/etc/mjb.yml') as file:
    config = yaml.safe_load(file)

# This is your test secret API key.
stripe.api_key = config['stripe']['api_key']

app = Flask(__name__,
            static_url_path='',
            static_folder='public')

YOUR_DOMAIN = config['stripe']['return_domain']

@app.route('/stripe/get-checkout-link', methods=['GET'])
def create_checkout_session():
    try:

        checkout_session = stripe.checkout.Session.create(
            line_items=[
                {
                    'price': request.args.get('lookup_key'),
                    'quantity': 1,
                },
            ],
            mode='subscription',
            success_url=YOUR_DOMAIN + '/subscription?status=success&session_id={CHECKOUT_SESSION_ID}',
            cancel_url=YOUR_DOMAIN  + '/subscription?status=error',
        )

        return jsonify({'status': 'success', 'url' : checkout_session.url })

    except Exception as e:
        return jsonify({'status': 'failure', 'error': e })

@app.route('/stripe/get-portal-link', methods=['GET'])
def customer_portal():
    customer_id = request.args.get('customer_id')

    # This is the URL to which the customer will be redirected after they are
    # done managing their billing with the portal.
    return_url = YOUR_DOMAIN + '/dashboard'

    portalSession = stripe.billing_portal.Session.create(
        customer=customer_id,
        return_url=return_url,
    )

    return jsonify({'status': 'success', 'url' : portalSession.url })

@app.route('/stripe/session-to-customer', methods=['GET'])
def session_to_customer():
    checkout_session_id = request.args.get('session_id')
    checkout_session = stripe.checkout.Session.retrieve(checkout_session_id)

    return jsonify({ 'customer_id' : checkout_session.customer })


if __name__ == '__main__':
    app.run()

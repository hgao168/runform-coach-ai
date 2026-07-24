const { test } = require('@playwright/test');
const {
  app,
  connectAndroid,
  expectVisible,
  fill,
  launchApp,
  tap
} = require('../src/android');

let device;

test.beforeAll(async () => {
  device = await connectAndroid();
});

test.afterAll(async () => {
  if (device) await device.close();
});

test.beforeEach(async () => {
  await launchApp(device);
});

test('@smoke login screen exposes stable automation targets', async () => {
  await expectVisible(device, app.tags.email);
  await expectVisible(device, app.tags.password);
  await expectVisible(device, app.tags.submit);
  await expectVisible(device, app.tags.register);
  await expectVisible(device, app.tags.forgotPassword);
});

test('@acceptance invalid credentials show a recoverable error', async () => {
  test.skip(
    !process.env.QA_EMAIL,
    'Set QA_EMAIL to run credential-dependent acceptance tests'
  );

  await fill(device, app.tags.email, process.env.QA_EMAIL);
  await fill(
    device,
    app.tags.password,
    process.env.QA_BAD_PASSWORD || 'definitely-not-the-password'
  );
  await tap(device, app.tags.submit);
  await expectVisible(device, app.tags.error);
  await expectVisible(device, app.tags.submit);
});

test('@acceptance valid user can log in and log out', async () => {
  test.skip(
    !process.env.QA_EMAIL || !process.env.QA_PASSWORD,
    'Set QA_EMAIL and QA_PASSWORD to run the login journey'
  );

  await fill(device, app.tags.email, process.env.QA_EMAIL);
  await fill(device, app.tags.password, process.env.QA_PASSWORD);
  await tap(device, app.tags.submit);
  await expectVisible(device, app.tags.home);
  await tap(device, app.tags.logout);
  await expectVisible(device, app.tags.email);
});

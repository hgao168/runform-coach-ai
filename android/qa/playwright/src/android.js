const { _android, expect } = require('@playwright/test');

function env(name, fallback) {
  return process.env[name] || fallback;
}

const app = {
  packageName: env('APP_PACKAGE', 'com.runform'),
  activity: process.env.APP_ACTIVITY,
  tags: {
    email: env('TAG_LOGIN_EMAIL', 'login_email'),
    password: env('TAG_LOGIN_PASSWORD', 'login_password'),
    submit: env('TAG_LOGIN_SUBMIT', 'login_submit'),
    error: env('TAG_LOGIN_ERROR', 'login_error'),
    home: env('TAG_HOME_SCREEN', 'home_screen'),
    logout: env('TAG_LOGOUT', 'profile_logout'),
    register: env('TAG_REGISTER_LINK', 'register_link'),
    forgotPassword: env('TAG_FORGOT_PASSWORD_LINK', 'forgot_password_link')
  }
};

function selector(tag) {
  // Compose exposes testTag as an Android resource id only when the app enables
  // testTagsAsResourceId on the relevant semantics subtree.
  return { res: tag };
}

async function connectAndroid() {
  const devices = await _android.devices();
  const serial = process.env.ANDROID_SERIAL;
  const candidates = serial
    ? devices.filter(device => device.serial() === serial)
    : devices;

  if (candidates.length !== 1) {
    await Promise.all(devices.map(device => device.close()));
    throw new Error(
      `Expected exactly one Android device${serial ? ` with serial ${serial}` : ''}; ` +
      `found ${candidates.length}. Set ANDROID_SERIAL when multiple devices are online.`
    );
  }

  for (const device of devices) {
    if (device !== candidates[0]) await device.close();
  }
  return candidates[0];
}

async function launchApp(device, { clearData = true } = {}) {
  await device.shell(`am force-stop ${app.packageName}`);
  if (clearData) await device.shell(`pm clear ${app.packageName}`);

  if (app.activity) {
    await device.shell(`am start -W -n ${app.packageName}/${app.activity}`);
  } else {
    await device.shell(
      `monkey -p ${app.packageName} -c android.intent.category.LAUNCHER 1`
    );
  }
}

async function waitFor(device, tag) {
  return device.wait({ selector: selector(tag), state: 'visible' });
}

async function fill(device, tag, value) {
  const element = await waitFor(device, tag);
  await element.fill(value);
}

async function tap(device, tag) {
  const element = await waitFor(device, tag);
  await element.tap();
}

async function expectVisible(device, tag) {
  await expect.poll(async () => {
    const element = await device.$(selector(tag));
    return Boolean(element);
  }).toBe(true);
}

module.exports = {
  app,
  connectAndroid,
  expectVisible,
  fill,
  launchApp,
  selector,
  tap,
  waitFor
};

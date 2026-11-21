# إعداد صدفة للنشر والتحديث التلقائي — دليل عربي

هذا الدليل يجهّز GitHub حتى يعمل مسار صدفة الآتي:

1. تحديث كود التطبيق في المستودع الخاص.
2. فحص الكود والاختبارات.
3. بناء APK موقّع.
4. موافقة مسؤول النشر.
5. رفع APK وملف التحديث وتوقيعه إلى Oracle.
6. اكتشاف التحديث من داخل تطبيق صدفة.

**مهم:** لا تضع أي مفتاح أو كلمة سر أو Token في المحادثات أو ملفات المشروع أو Issues. أضف القيم مباشرة إلى خانة Secret المناسبة في GitHub. لا تغيّر Visibility للمستودع العام؛ يجب أن يبقى `sodfa-build` عاماً حتى يستمر مسار GitHub-hosted Actions المجاني.

## أولاً: إعداد المستودع العام

افتح المستودع:

`loudply0-eng/sodfa-build`

ثم:

**Settings → Environments → New environment**

أنشئ بيئتين بالأسماء التالية حرفياً:

### البيئة `sodfa-validation`

- Deployment branches: اختر `Selected branches and tags` وحدد `main` فقط.
- Required reviewers: أضف حسابك كمراجع موافقة.
- Environment secrets: أضف Secret واحداً فقط:

| الاسم | مصدره وصلاحيته |
|---|---|
| `SODFA_VALIDATION_SOURCE_READ_TOKEN` | Fine-grained PAT مستقل، محدد للمستودع الخاص `loudply0-eng/sodfa-` فقط، وصلاحية Contents: Read-only |

لا تضف إلى هذه البيئة مفتاح توقيع Android أو مفتاح Ed25519 الخاص أو SSH الخاص بالسيرفر.

### البيئة `sodfa-production`

- Deployment branches: اختر `Selected branches and tags` وحدد `main` فقط.
- Required reviewers: أضف حسابك كمراجع موافقة.
- Environment secrets: أضف الأسرار التالية:

| الاسم | القيمة المطلوبة |
|---|---|
| `SODFA_PROD_SOURCE_READ_TOKEN` | Fine-grained PAT مستقل، للمستودع الخاص وحده، Contents: Read-only |
| `SODFA_PROD_ANDROID_KEYSTORE_BASE64` | Keystore المستخدم لتوقيع إصدارات صدفة بترميز Base64 |
| `SODFA_PROD_ANDROID_KEYSTORE_PASSWORD` | كلمة مرور Keystore |
| `SODFA_PROD_ANDROID_KEY_ALIAS` | اسم Alias |
| `SODFA_PROD_ANDROID_KEY_PASSWORD` | كلمة مرور المفتاح |
| `SODFA_PROD_UPDATE_PRIVATE_KEY_PEM` | المفتاح الخاص Ed25519 بصيغة PEM |
| `SODFA_PROD_DEPLOY_HOST` | عنوان خادم Oracle |
| `SODFA_PROD_DEPLOY_USER` | مستخدم SSH للنشر |
| `SODFA_PROD_DEPLOY_SSH_KEY` | مفتاح SSH الخاص بمستخدم النشر |
| `SODFA_PROD_DEPLOY_KNOWN_HOSTS` | سطر/أسطر known_hosts موثوقة ومتحقق منها مسبقاً |

أضف Environment variable واحداً (ليس Secret):

| الاسم | القيمة المطلوبة |
|---|---|
| `SODFA_PROD_UPDATE_PUBLIC_KEY_BASE64` | المفتاح العام Ed25519 المقابل للمفتاح الخاص أعلاه، 32 بايت بصيغة Base64 |

**لا تضع المفتاح الخاص Ed25519 في متغير عام ولا تضعه داخل التطبيق.** التطبيق يستلم المفتاح العام فقط عند بناء APK.

## ثانياً: إنشاء رموز القراءة

أنشئ رمزين مختلفين Fine-grained PAT من إعدادات حساب GitHub، ولا تعِد استخدام رمز بصلاحيات واسعة:

### رمز التحقق

- Repository access: Only select repositories → `sodfa-`
- Repository permissions: Contents → Read-only
- خزّنه في `sodfa-validation` باسم `SODFA_VALIDATION_SOURCE_READ_TOKEN`.

### رمز الإنتاج

- Repository access: Only select repositories → `sodfa-`
- Repository permissions: Contents → Read-only
- خزّنه في `sodfa-production` باسم `SODFA_PROD_SOURCE_READ_TOKEN`.

لا تمنح أيّاً من الرمزين صلاحية Contents: Write.

## ثالثاً: إعداد المستودع الخاص

افتح:

`loudply0-eng/sodfa-`

ثم:

**Settings → Secrets and variables → Actions → Repository secrets**

أضف:

| الاسم | الغرض |
|---|---|
| `SODFA_BUILDER_RELEASE_DISPATCH_TOKEN` | Fine-grained PAT مستقل، محدد للمستودع العام `sodfa-build` فقط، بصلاحية Actions: Read and write، ومن دون Contents: Write |
| `SODFA_PROD_ORACLE_SSH_KEY` | مفتاح SSH المستخدم لمسارات تشخيص/إدارة Oracle الموجودة في المستودع الخاص |
| `SODFA_PROD_ORACLE_KNOWN_HOSTS` | بصمة/سطر المضيف الموثوق لمسارات Oracle |

رمز `SODFA_BUILDER_RELEASE_DISPATCH_TOKEN` مخصص لإطلاق Workflow البناء العام فقط. لا تستخدمه للوصول إلى كود المصدر، ولا تمنحه صلاحية كتابة الملفات أو المستودعات.

المستودع الخاص حالياً على GitHub Free؛ لذلك لا نستخدم Environments خاصة به. مفاتيح Oracle الخاصة بمسارات الإدارة تبقى Repository secrets منفصلة عن مفاتيح بناء APK والنشر العام.

## رابعاً: اختبار التحقق قبل النشر

بعد إضافة إعدادات `sodfa-validation`:

1. افتح المستودع العام `sodfa-build`.
2. انتقل إلى **Actions → SODFA Private Source Validation**.
3. اختر Run workflow على فرع البناء `main`.
4. أدخل في `source_ref` اسم الفرع:
   `security/hardening-baseline-2026-11`
5. اجعل `confirm_validation` = `true`.
6. وافق على تشغيل بيئة `sodfa-validation` عندما يطلب GitHub ذلك.

يجب أن ينجح تدقيق API، وPostgreSQL/Redis migrations والاختبارات، وFlutter analyze وtests وبناء Debug وRelease تجريبي. هذا الاختبار لا يستخدم مفاتيح الإنتاج ولا يرفع APK للسيرفر.

## خامساً: النشر التلقائي

بعد مراجعة ودمج PR مستودع البناء العام ثم PR المصدر الخاص، أي تحديث لملفات التطبيق المحددة في فرع `main` الخاص يطلق مسار البناء العام تلقائياً.

قبل وصول الأسرار إلى مهمة النشر، يجب أن توافق على بيئة `sodfa-production`. بعدها يجري فحص API وبناء APK وتوقيعه والتحقق من شهادة Android وتوقيع manifest ونشره على Oracle.

النشر لا يثبت التحديث بصمت: Android يعرض مُثبّت الحزمة ويطلب تأكيد المستخدم.

## ملاحظات أمان أخيرة

- لا تشغّل مسارات النشر القديمة الموجودة حالياً في `main` قبل دمج مساري الحماية.
- لا ترفع مفاتيح التوقيع أو SSH أو ملفات `.jks` إلى المستودع.
- لا تغيّر رقم البناء لإصدار جديد إلى رقم مستخدم سابقاً؛ زد رقم `build_number` وأضف سجل تغييرات مطابقاً.
- لا تنفّذ إعادة كتابة تاريخ Git العام قبل أخذ نسخة احتياطية ومراجعة الخطة؛ هذه عملية مستقلة وليست جزءاً من الدمج العادي.
- لا تُعدّ صدفة منشورة أو تحديثاتها فعّالة قبل نجاح فحص المصدر والنشر والتحقق من الملفات المنشورة على السيرفر.

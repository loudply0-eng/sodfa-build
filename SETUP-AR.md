# دليل بناء وفحص ونشر صدفة عبر المستودع العام — عربي

هذا الدليل يجهّز GitHub حتى يعمل مسار صدفة الآتي:

1. يبقى كود التطبيق في المستودع الخاص.
2. يسحب المستودع العام نسخة محددة من المصدر الخاص بواسطة رمز قراءة فقط.
3. تُنفّذ اختبارات API وFlutter والبناء على GitHub-hosted runner في المستودع العام.
4. عند طلب إصدار، يبدأ Workflow الإنتاج يدوياً من المستودع العام بعد تثبيت SHA المصدر.
5. تتم الموافقة على بيئة الإنتاج، ثم يوقّع APK وملف التحديث وينشران إلى Oracle.
6. يكتشف تطبيق صدفة التحديث ويطلب من Android تأكيد التثبيت.

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
| `SODFA_PROD_ORACLE_SSH_KEY` | مفتاح SSH المستخدم لمسارات تشخيص/إدارة Oracle الموجودة في المستودع الخاص |
| `SODFA_PROD_ORACLE_KNOWN_HOSTS` | بصمة/سطر المضيف الموثوق لمسارات Oracle |

لا يحتاج المستودع الخاص إلى رمز لإطلاق البناء العام؛ لن نعتمد على أي GitHub Actions runner في المستودع الخاص. إذا كان السر القديم `SODFA_BUILDER_RELEASE_DISPATCH_TOKEN` موجوداً، احذفه بعد التأكد من عدم وجود استخدام آخر له.

المستودع الخاص حالياً على GitHub Free؛ لذلك لا نستخدم Environments خاصة به. مفاتيح Oracle الخاصة بمسارات الإدارة تبقى Repository secrets منفصلة عن مفاتيح بناء APK والنشر العام.

## رابعاً: اختبار التحقق قبل النشر

بعد إضافة إعدادات `sodfa-validation`:

1. افتح المستودع العام `sodfa-build`.
2. انتقل إلى **Actions → SODFA Private Source Validation**.
3. اختر Run workflow على فرع البناء `main`.
4. أدخل في `source_ref` قيمة SHA كاملة من 40 حرفاً للنسخة المراد فحصها. من Termius يمكن جلب SHA الحالي للمصدر بالأمر:

   ```bash
   gh api repos/loudply0-eng/sodfa-/commits/main --jq .sha
   ```
5. اجعل `confirm_validation` = `true`.
6. وافق على تشغيل بيئة `sodfa-validation` عندما يطلب GitHub ذلك.

يجب أن ينجح تدقيق API، وPostgreSQL/Redis migrations والاختبارات، وFlutter analyze وtests وبناء Debug وRelease تجريبي. هذا الاختبار لا يستخدم مفاتيح الإنتاج ولا يرفع APK للسيرفر.

## خامساً: إطلاق الفحص والإصدار من المستودع العام فقط

لا نشغّل فحوص API أو Flutter أو بناء APK أو مهمة إطلاق من المستودع الخاص؛ ذلك المستودع يبقى للمصدر فقط، حتى لا تُستهلك حصته المدفوعة. ملفات CI القديمة ومهمة الإطلاق الخاصة تُزال من المصدر. جميع مهام البناء والفحص والإصدار تعمل من `sodfa-build` باستخدام Standard GitHub-hosted runners في المستودع العام.

بعد حفظ تغييرات المصدر ودمجها في `main` الخاص، استخدم Termius لجلب SHA دقيق ثم شغّل فحص المصدر من المستودع العام:

```bash
SOURCE_SHA="$(gh api repos/loudply0-eng/sodfa-/commits/main --jq .sha)"
echo "Source commit: $SOURCE_SHA"
gh workflow run sodfa-source-validation.yml \\
  --repo loudply0-eng/sodfa-build \\
  --ref main \\
  --field source_ref="$SOURCE_SHA" \\
  --field confirm_validation=true
```

تابع النتيجة:

```bash
gh run list --repo loudply0-eng/sodfa-build \\
  --workflow sodfa-source-validation.yml --limit 5
```

لا تطلق الإصدار قبل نجاح فحص المصدر على SHA نفسه. بعد نجاحه، ابدأ الإصدار من المستودع العام بهذا الأمر فقط عندما تكون مستعداً للنشر:

```bash
gh workflow run sodfa-secure-release.yml \\
  --repo loudply0-eng/sodfa-build \\
  --ref main \\
  --field confirm_release=true \\
  --field source_ref="$SOURCE_SHA"
```

قد يطلب GitHub موافقتك على بيئة `sodfa-production`؛ لا توافق إلا بعد مراجعة SHA وملخص الإصدار. مسار الإنتاج يبني APK موقّعاً، يتحقق من التوقيع وملف manifest، ثم ينشر إلى Oracle. تشغيله يستهلك وقت GitHub Actions للمستودع العام، ولا يستهلك حصة المستودع الخاص عند استخدام Standard GitHub-hosted runner.

النشر لا يثبت التحديث بصمت: Android يعرض مُثبّت الحزمة ويطلب تأكيد المستخدم.

## طريقة تجهيز أي تحديث جديد لاحقاً

عند تجهيز إصدار جديد في المستودع الخاص:

1. زد رقم الإصدار ورقم البناء معاً في `pubspec.yaml`، ولا تعِد استعمال رقم بناء سبق نشره.
2. أضف سجلاً واحداً مطابقاً في أعلى `docs/CHANGELOG.json` بنفس `version` و`build_number`.
3. اكتب التغييرات بالعربية داخل `changes`.
4. اترك إعدادات التحديث الاختيارية كما يلي في الوضع الاعتيادي:

```json
{
  "force_update": false,
  "min_supported_build": 1,
  "rollout_percentage": 100
}
```

- `force_update`: اجعله `true` فقط عندما تكون النسخة الجديدة جاهزة ولا يجوز للمستخدم تأجيلها.
- `min_supported_build`: ارفع الرقم لإجبار النسخ الأقدم من هذا البناء على التحديث.
- `rollout_percentage`: استخدم 10 أو 25 أو 50 لإطلاق تدريجي، ثم 100 عند التعميم.

مسار البناء يتحقق من الأنواع والحدود قبل توقيع ملف التحديث. لا ترفع الحد الأدنى إلى رقم أعلى من رقم بناء الإصدار نفسه.

## سادساً: حماية فرع main من التغيير المباشر

هذه الخطوة مهمة حتى لا يرجع كود التطبيق إلى المستودع العام أو تعود مهام CI المدفوعة داخل المستودع الخاص.

في كل مستودع افتح:

**Settings → Branches → Add branch protection rule**

واجعل Branch name pattern هو `main`.

### في المستودع العام `sodfa-build`

- فعّل Require a pull request before merging.
- فعّل Require status checks to pass before merging، واختر فحص `policy` الذي ينفذه `SODFA Builder Security Checks`.
- فعّل Require branches to be up to date before merging.
- فعّل Require conversation resolution before merging.
- امنع Force pushes.
- امنع Deletions.
- لا تسمح بإدخال تغييرات على `main` مباشرةً.

### في المستودع الخاص `sodfa-`

- فعّل Require a pull request before merging.
- فعّل Require conversation resolution before merging.
- امنع Force pushes.
- امنع Deletions.
- لا تدمج تحديثاً قبل نجاح **SODFA Private Source Validation** من المستودع العام على نفس Source commit. إعداد حماية `main` في الخاص قد يتطلب ترقية خطة GitHub؛ إبقاء المستودع خاصاً أهم من فتحه للعامة.

إذا ما عندك مراجع ثانٍ موثوق، لا تفعّل شرط موافقة شخص آخر يسبب قفل دمج التحديثات عليك. خَلِّ شرط الـPR وفحوصات البناء والحماية فعالاً، وأضف مراجعة ثانية عند توفر شخص موثوق.

ملاحظة: لا أستطيع من اتصال GitHub الحالي قراءة أو تعديل Branch protection؛ اضبطها من إعدادات GitHub نفسها. بعد ذلك تحقّق أن القاعدة تظهر مفعّلة على `main`.

## ملاحظات أمان أخيرة

- لا تعِد إضافة `sodfa-api-ci.yml` أو `sodfa-ci.yml` أو `sodfa-release-dispatch.yml` إلى المستودع الخاص؛ الفحص والبناء والإصدار مسؤولية المستودع العام.
- لا ترفع مفاتيح التوقيع أو SSH أو ملفات `.jks` إلى المستودع.
- لا تغيّر رقم البناء لإصدار جديد إلى رقم مستخدم سابقاً؛ زد رقم `build_number` وأضف سجل تغييرات مطابقاً.
- لا تنفّذ إعادة كتابة تاريخ Git العام قبل أخذ نسخة احتياطية ومراجعة الخطة؛ هذه عملية مستقلة وليست جزءاً من الدمج العادي.
- لا تُعدّ صدفة منشورة أو تحديثاتها فعّالة قبل نجاح فحص المصدر والنشر والتحقق من الملفات المنشورة على السيرفر.

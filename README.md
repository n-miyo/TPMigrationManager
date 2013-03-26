TPMigrationManager
====================

DESCRIPTION
--------------------

The `TPMigrationManager` class provides easy way for
`CoreData` migration.

There are two migration ways.

- Inferred mapping model migration.
- Specific mapping model migration.

'Inferred mapping model migration' is an easy and fast
migration way.  You can use this way with
migrateByInferredMappingModelWithOptions:completed: method.

Fot this way, you don't need to prepare any migration
model.  CoreData framework checks the differences between
old and new model and tries to migrate automatically.  It
is Apple's recommendation.  If model is not changed so
much, you should use this way.  For this migration way, you
_cannot_ terminate the migration process by cancel method
and migrationProgress property is not changed at all.

'Specific mapping model migration' is a flexible migration
way.  You can use this way with
migrateBySpecificMappingModelWithOptions:progress:completed:
method.

With this way, you can convert any old model to new one by
offering specific migration model by yourself.  You can
terminate the migration process anytime by cancel method,
and migrationProgress property will be updated
periodically.

Before starting migration, you should use migrationStatus
for checking which migration way you can use in your
environment.

During migration, temporary persistent store file is
created and the file is used for migration.  After
migration completed, the temporary persistent overwites old
one.  If migration is terminated by cancel method or failed
by error, old persistent remains as it is.  If you'd like
to remain old persistent file, you can specify
`TPMigrationManagerBackupPersitentStoreExtensionOption`
option in migration method.


PLATFORM
--------------------

iOS 5 and above.  You have to enable ARC.


PREPARATION
--------------------

Copy TPMigrationManager.h and TPMigrationManager.m in
TPMigrationManager directory to your project.


USAGE
--------------------

See API document.


AUTHOR
--------------------

MIYOKAWA, Nobuyoshi

* E-Mail: n-miyo@tempus.org
* Twitter: nmiyo
* Blog: http://blogger.tempus.org/


COPYRIGHT
--------------------

MIT LICENSE

Copyright (c) 2013 MIYOKAWA, Nobuyoshi (http://www.tempus.org/)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

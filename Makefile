#

PROJECTNAME="TPMigrationManager"
PROJECTCOMPANY="MIYOKAWA, Nobuyoshi"
COMPNAYID="org.tempus"
OUTPUTDIR="Documents"
TARGETDIR="TPMigrationManager"

all:
	@echo "usage: ${MAKE} doc|install-doc"

doc:
	INSTALLOPTION="--no-install-docset" ${MAKE} gendoc

install-doc:
	INSTALLOPTION="--install-docset" ${MAKE} gendoc

gendoc:
	mkdir -p ${OUTPUTDIR}
	appledoc \
	--project-name ${PROJECTNAME} \
	--project-company ${PROJECTCOMPANY} \
	--company-id ${COMPNAYID} \
	--output ${OUTPUTDIR} \
	${INSTALLOPTION} \
	${TARGETDIR}

# EOF

local Logger = PVP.use('Logger')

SetGameType('7PVP')
PVP.boot()
Logger.info('Serveur démarré (%d modules)', #PVP.order)

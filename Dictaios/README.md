# Dictaios - Application de Dictaphone iOS

Une application SwiftUI pour enregistrer, sauvegarder et lire des notes vocales sur iOS.

## Fonctionnalités

- Enregistrement audio avec AVAudioRecorder
- Sauvegarde des fichiers au format .m4a dans le répertoire Documents
- Liste des enregistrements avec date et durée
- Lecture des enregistrements avec contrôles et barre de progression
- Suppression des enregistrements par swipe ou menu contextuel
- Interface utilisateur épurée et responsive

## Comment utiliser ce projet

### Prérequis

- Xcode 13.0 ou supérieur
- iOS 15.0 ou supérieur (pour le déploiement)

### Installation

1. Ouvrez le fichier `Dictaios.xcodeproj` dans Xcode
2. Sélectionnez un simulateur ou un appareil iOS
3. Cliquez sur le bouton "Run" (▶️) ou appuyez sur Cmd+R pour compiler et exécuter l'application

### Utilisation de l'application

1. Appuyez sur le bouton d'enregistrement (cercle rouge) pour commencer à enregistrer
2. Parlez dans le microphone de votre appareil
3. Appuyez à nouveau sur le bouton pour arrêter l'enregistrement
4. Vos enregistrements apparaîtront dans la liste
5. Appuyez sur le bouton de lecture pour écouter un enregistrement
6. Faites glisser vers la gauche ou utilisez le menu contextuel pour supprimer un enregistrement

## Structure du projet

- **Models/**
  - `AudioRecording.swift` - Modèle représentant un enregistrement audio
  - `AudioFileManager.swift` - Gestion des fichiers audio
- **ViewModels/**
  - `RecorderViewModel.swift` - Logique d'enregistrement et de lecture
- **Views/**
  - `MainView.swift` - Interface principale
  - `RecordButton.swift` - Bouton d'enregistrement personnalisé
  - `PlayerView.swift` - Interface de lecture des enregistrements

## Permissions

L'application nécessite l'accès au microphone pour fonctionner. La permission est demandée lors de la première tentative d'enregistrement.

## Remarques

- Les enregistrements sont sauvegardés au format .m4a dans le répertoire Documents de l'application
- L'application fonctionne en mode portrait et paysage
- L'interface est optimisée pour iPhone, mais fonctionne également sur iPad

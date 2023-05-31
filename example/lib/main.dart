import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:ed_screen_recorder/ed_screen_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  EdScreenRecorder? screenRecorder;
  Map<String, dynamic>? _response;
  bool inProgress = false;
  bool isRecorded = false;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    screenRecorder = EdScreenRecorder();
  }

  Future<void> startRecord({required String fileName}) async {
    final path =
        '${(await getTemporaryDirectory()).path}/math_tutor_temp';
    final savingDirectory = Directory(path);
    if (!await savingDirectory.exists()) {
      await savingDirectory.create(recursive: true);
    }
    try {
      var startResponse = await screenRecorder?.startRecordScreen(
        fileName: "temp",
        //Optional. It will save the video there when you give the file path with whatever you want.
        //If you leave it blank, the Android operating system will save it to the gallery.
        dirPathToSave: path,
        audioEnable: true,
      );
      setState(() {
        _response = startResponse;
      });
      try {
        screenRecorder?.watcher?.events.listen(
          (event) {
            log(event.type.toString(), name: "Event: ");
          },
          onError: (e) => kDebugMode ? debugPrint('ERROR ON STREAM: $e') : null,
          onDone: () => kDebugMode ? debugPrint('Watcher closed!') : null,
        );
      } catch (e) {
        kDebugMode ? debugPrint('ERROR WAITING FOR READY: $e') : null;
      }
    } on PlatformException {
      kDebugMode
          ? debugPrint("Error: An error occurred while starting the recording!")
          : null;
    }
  }

  Future<void> stopRecord() async {
    try {
      var stopResponse = await screenRecorder?.stopRecord();

      setState(() {
        _response = stopResponse;
        isRecorded = true;
        _controller = VideoPlayerController.file(
          stopResponse?['file'],
        );
      });
    } on PlatformException {
      kDebugMode
          ? debugPrint("Error: An error occurred while stopping recording.")
          : null;
    }
  }

  Future<void> pauseRecord() async {
    try {
      await screenRecorder?.pauseRecord();
    } on PlatformException {
      kDebugMode
          ? debugPrint("Error: An error occurred while pause recording.")
          : null;
    }
  }

  Future<void> resumeRecord() async {
    try {
      await screenRecorder?.resumeRecord();
    } on PlatformException {
      kDebugMode
          ? debugPrint("Error: An error occurred while resume recording.")
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Screen Recording Debug"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("File: ${(_response?['file'] as File?)?.path}"),
            Text("Status: ${(_response?['success']).toString()}"),
            Text("Event: ${_response?['eventname']}"),
            Text("Progress: ${(_response?['progressing']).toString()}"),
            Text("Message: ${_response?['message']}"),
            Text("Video Hash: ${_response?['videohash']}"),
            Text("Start Date: ${(_response?['startdate']).toString()}"),
            Text("End Date: ${(_response?['enddate']).toString()}"),
            ElevatedButton(
                onPressed: () => startRecord(fileName: "eren"),
                child: const Text('START RECORD')),
            ElevatedButton(
                onPressed: () => resumeRecord(),
                child: const Text('RESUME RECORD')),
            ElevatedButton(
                onPressed: () => pauseRecord(),
                child: const Text('PAUSE RECORD')),
            ElevatedButton(
                onPressed: () => stopRecord(),
                child: const Text('STOP RECORD')),
            if (isRecorded && _controller != null) ...[
              Expanded(
                child: VideoPlayer(_controller!),
              ),
              // Play Button
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

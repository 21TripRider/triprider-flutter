import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Trip/widgets/F_Course_Card.dart';

class SaveCourseScreen extends StatelessWidget {
  const SaveCourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 28),
        ),
        centerTitle: true,
        title: Text('저장한 코스', style: TextStyle(fontWeight: FontWeight.bold)),
      ),

      body: ListView(

        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10,bottom: 10,top: 10),
                child: Text('내가 좋아요한 코스',style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),),
              ),

              Row(
                children: [
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                ],
              ),

              Row(
                children: [
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                ],
              ),

              Row(
                children: [
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                ],
              ),

              Row(
                children: [
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                  FCourseCard(favorite_Pressed: favorite_Pressed, course_Pressed: course_Pressed),
                ],
              ),


            ],
          )
        ],
      )


    );
  }

  favorite_Pressed(){

  }

  course_Pressed(){

  }


}
